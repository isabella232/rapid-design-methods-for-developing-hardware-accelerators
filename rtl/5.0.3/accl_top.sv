// See LICENSE for license details.
// ***************************************************************************
// Copyright (c) 2013-2016, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// * Neither the name of Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Module Name:         accl_top.v
// Project:             Generic Accelerator AFU
//                      Compliant with CCI-P spec v0.58
// Description:         top level wrapper for ACCL, it instantiates requestor
//                      & accelerator block
// ***************************************************************************
//
// Change Log
// Date             Comments
// 7/2/2014         Supports extended 64KB CSR space. Remapped all NLB CSRs
//
// ---------------------------------------------------------------------------------------------------------------------------------------------------
//                                         NLB - Native Loopback test
//  ------------------------------------------------------------------------------------------------------------------------------------------------
//
// This is a reference CCI-S AFU implementation compatible with CCI specification v2.10
// The purpose of this design is to generate different memory access patterns for validation.
// The test can also be used to measure following performance metrics:
// Bandwidth: 100% Read, 100% Write, 50% Read + 50% Write
// Latency: Read, Write
//
//   Block Diagram:
//
//   +------------------------------------------------------------------+                       
//   |                       +-----------------------------------+      |
//   |    +----------+       |   +---------+      +------------+ |      |                           
//   |    |          |  Wr   |   |         |<---->| ACCEL      | |      |                           
//  CCI-P |Requestor |<------|-->| Memory  |      +------------+ |      |                            
// <----->|          |  Rd   |   | Unit    |                     |      |                       
//   |    |          |<------|-->|         |                     |      |                       
//   |    +----------+       |   +---------+       SystemC/HLS   |      |                       
//   |                       +-----------------------------------+      |               
//   |                                                                  |
//   |                                                                  |                     
//   |                                                                  |
//   | accl_top                                                        |
//   +------------------------------------------------------------------+
//
//
//  NLB Revision and feature tracking
//-------------------------------------------------------------------------------------------
//      Rev     CCI spec        Comments
//-------------------------------------------------------------------------------------------
//      1.0     0.9             Uses proprietary memory mapped CSR read mapping
//      1.1     2.0             Device Status Memory Compliant
//      1.2     CCI-P v0.58     Updates to CCI-P spec
//
// CSR Address Map
//------------------------------------------------------------------------------------------
// Byte Address       Attribute         Name                 Width   Comments
//     'h0000          RO                DFH                 64b     AFU Device Feature Header
//     'h0008          RO                AFU_ID_L            64b     AFU ID low 64b
//     'h0010          RO                AFU_ID_H            64b     AFU ID high 64b
//     'h0018          RsvdZ             CSR_DFH_RSVD0       64b     Mandatory Reserved 0
//     'h0020          RO                CSR_DFH_RSVD1       64b     Mandatory Reserved 1
//     'h0100          RW                CSR_SCRATCHPAD0     64b     Scratchpad register 0
//     'h0108          RW                CSR_SCRATCHPAD0     64b     Scratchpad register 2
//     'h0110          RW                CSR_AFU_DSM_BASEL   32b     Lower 32-bits of AFU DSM base address. The lower 6-bbits are 4x00 since the address is cache aligned.
//     'h0114          RW                CSR_AFU_DSM_BASEH   32b     Upper 32-bits of AFU DSM base address.
//     'h0120:         RW                CSR_UNUSED_ULL0     64b     
//     'h0128:         RW                CSR_UNUSED_ULL1     64b
//     'h0130:         RW                CSR_UNUSED_U        32b     
//     'h0138:         RW                CSR_CTL             32b     Controls test flow, start, stop, force completion
//     'h0140:         RW                CSR_CFG             32b     Configures test parameters
//     'h0148:         RW                CSR_INACT_THRESH    32b     inactivity threshold limit
//     'h0150          RW                CSR_INTERRUPT0      32b     SW allocates Interrupt APIC ID & Vector to device
//     
//
// DSM Offeset Map
// ***CCIP v0.6*** Note DSM is NOT mandatory. User can still define a workspace and use it for DSM.
//------------------------------------------------------------------------------------------
//      Byte Offset   Attribute         Name                  Comments
//      0x40          RO                DSM_STATUS            test status and error register
//
// CSR_CTL:
// [31:3]   RW    Rsvd
// [2]      RW    Force test completion. Writes test completion flag and other performance counters to csr_stat. It appears to be like a normal test completion.
// [1]      RW    Starts test execution.
// [0]      RW    Active low test Reset. All configuration parameters change to reset defaults.
//
//
// CSR_CFG:
// [29]     RW    cr_interrupt_testmode - used to test interrupt. Generates an interrupt at end of each test.
// [28]     RW    cr_interrupt_on_error - send an interrupt when error detected
// [27:20]  RW    cr_test_cfg  -may be used to configure the behavior of each test mode
// [13:12]  RW    cr_chsel     -select virtual channel
// [10:9]   RW    cr_rdsel     -configure read request type. 0- RdLine_S, 1- RdLine_I, 2- RdLine_O, 3- Mixed mode
// [8]      RW    cr_delay_en  -enable random delay insertion between requests
// [6:5]    RW    cr_multiCL_len  - Multi CL length. Valid values are 0,1,3
// [4:2]    RW    cr_mode      -configures test mode
// [1]      RW    cr_cont      - 1- test rollsover to start address after it reaches the CSR_NUM_LINES count. Such a test terminates only on an error.
//                               0- test terminates, updated the status csr when CSR_NUM_LINES count is reached.
// [0]      RW    cr_wrthru_en -switch between WrLine_I & WrLine_M  request types. 
//                              0- WrLine_M
//                              1- WrLine_I
//
// CSR_INACT_THRESHOLD:
// [31:0]   RW  inactivity threshold limit. The idea is to detect longer duration of stalls during a test run. Inactivity counter will count number of consecutive idle cycles,
//              i.e. no requests are sent and no responses are received. If the inactivity count > CSR_INACT_THRESHOLD then it sets the inact_timeout signal. The inactivity counter
//              is activated only after test is started by writing 1 to CSR_CTL[1].
//
// CSR_INTERRUPT0:
// [23:16]  RW    vector      - Interrupt Vector # for the device
// [15:0]   RW    apic id     - Interrupt APIC ID for the device 
//
// DSM_STATUS:
// [511:256] RO  Error dump from Test Mode
// [255:224] RO  end overhead
// [223:192] RO  start overhead
// [191:160] RO  Number of writes
// [159:128] RO  Number of reads
// [127:64]  RO  Number of clocks
// [63:32]   RO  test error register
// [31:16]   RO  Compare and Exchange success Counter
// [15:1]    RO  Unique id for each dsm status write
// [0]       RO  test completion flag
//
// High Level Test flow:
//---------------------------------------------------------------
// 1.   SW Reads DFH at AFU offset 0x0
// 2.   SW REad AFU ID at offset 0x8 & 0x10
// 3.   SW initalizes Device Status Memory (DSM) to zero.
// 4.   SW writes DSM BASE address to AFU. CSR Write(DSM_BASE_H), CSR Write(DSM_BASE_L)
// 5.   SW prepares source & destination memory buffer- this is test specific.
// 4.   SW CSR Write(CSR_CTL)=3'h1. This brings the test out of reset and puts it in configuration mode. Configuration is allowed only when CSR_CTL[0]=1 & CSR_CTL[1]=0.
// 5.   SW configures the test parameters, i.e. src/dest address, csr_cfg, num lines etc. 
// 6.   SW CSR Write(CSR_CTL)=3'h3. AFU begins test execution.
// 7.   Test completion:
//      a. HW completes- When the test completes or detects an error, the HW AFU writes to DSM_STATUS. SW is polling on DSM_STATUS[31:0]==1.
//      b. SW forced completion- The SW forces a test completion, CSR Write(CSR_CTL)=3'h7. HW AFU writes to DSM_STATUS.
//      The test completion method used depends on the test mode. Some test configuration have no defined end state. When using continuous mode, you must use 7.b. 
//                              
// Test modes:
//---------------------------------------------------------------
//      Test Mode       Encoding- CSR_CFG[4:2]        #cache line threshold- CSR_NUM_LINES[N-1:0]       #cache line threshold for N=14
//      --------------------------------------------------------------------------------------------------------------------------------------
// 1.     LPBK1         3'b000                          2^N                                             14'h3fff
// 2.     READ          3'b001                          2^N                                             14'h3fff
// 3.     WRITE         3'b010                          2^N                                             14'h3fff
// 4.     TRPUT         3'b011                          2^N                                             14'h3fff
// 5.     SW1           3'b111                          2^N                                             14'h3ffe
//
// 1. LPBK1:
// This is a memory copy test. AFU copies CSR_NUM_LINES from source buffer to destination buffer. On test completion, the software compares the source and destination buffers.
//
// 2. READ:
// This is a read only test with NO data checking. AFU reads CSR_NUM_LINES starting from CSR_SRC_ADDR. This test is used to stress the read path and 
// measure 100% read bandwidth or latency.
//
// 3. WRITE:
// This is a write only test with NO data checking. AFU writes CSR_NUM_LINES starting from CSR_DST_ADDR location. This test is used to stress the write path and
// measure 100% write bandwidth or latency.
// 
// 4. TRPUT:
// This test combines the read and write streams. There is NO data checking and no dependency between read & writes. It reads CSR_NUM_LINES starting from CSR_SRC_ADDR location and 
// writes CSR_NUM_LINES to CSR_DST_ADDR. It is also used to measure 50% Read + 50% Write bandwdith.
//
// 7. SW1:
// This test measures the full round trip data movement latency between CPU & FPGA. 
// The test can be configured to use different 4 different CPU to FPGA messaging methods- 
//      a. polling from AFU
//      b. UMsg without Data
//      c. UMsg with Data
//      d. CSR Write
// test flow:
// 1. Wait on test_go
// 2. Start timer. Write N cache lines. WrData= {16{32'h0000_0001}}
// 3. Write Fence.
// 4. FPGA -> CPU Message. Write to address N+1. WrData = {{14{32'h0000_0000}},{64{1'b1}}}
// 5. CPU -> FPGA Message. Configure one of the following methods:
//   a. Poll on Addr N+1. Expected Data [63:32]==32'hffff_ffff
//   b. CSR write to Address 0xB00. Data= Dont Care
//   c. UMsg Mode 0 (with data). UMsg ID = 0
//   d. UMsgH Mode 1 (without data). UMsg ID = 0
// 7. Read N cache lines. Wait for all read completions.
// 6. Stop timer Send test completion.
//
`include "vendor_defines.vh"
`include "hld_defines.vh"

import ccip_if_pkg::*;


typedef enum bit [2:0] { CLK_400=3'b000, CLK_273=3'b001, CLK_200=3'b010, CLK_136=3'b011, CLK_100=3'b100 } AFUClocks;

module accl_top #(parameter TXHDR_WIDTH=61, RXHDR_WIDTH=18, DATA_WIDTH =512, NEXT_DFH_BYTE_OFFSET=24'h0)
(
                
       // ---------------------------global signals-------------------------------------------------
       Clk_400,                         //              in    std_logic;           Core clock. CCI interface is synchronous to this clock.
       SoftReset,                        //              in    std_logic;           CCI interface reset. The Accelerator IP must use this Reset. ACTIVE HIGH
       // ---------------------------IF signals between CCI and AFU  --------------------------------
       cp2af_sRxPort,
       af2cp_sTxPort,

  pClkDiv2, //200Mhz

  pClkDiv4, //100Mhz

  uClk_usr, //273Mhz
  uClk_usrDiv2, // 136Mhz
  
  ivp_req_valid,
  ivp_req_ready
);

   input                        Clk_400;             //              in    std_logic;           Core clock. CCI interface is synchronous to this clock.
   input                        SoftReset;            //              in    std_logic;           CCI interface reset. The Accelerator IP must use this Reset. ACTIVE HIGH

   input  t_if_ccip_Rx          cp2af_sRxPort;
   output t_if_ccip_Tx          af2cp_sTxPort;

   input pClkDiv2;
   input pClkDiv4;
   input uClk_usr;
   input uClk_usrDiv2;

   input ivp_req_valid;
   input ivp_req_ready;

   localparam      PEND_THRESH = 7;
   localparam      ADDR_LMT    = 42;
   localparam      MDATA       = 'd11;
   localparam      ACC_CLK = `HLD_ACC_CLK;
   //--------------------------------------------------------
   // Test Modes
   //--------------------------------------------------------
   localparam              M_LPBK1         = 3'b000;
   localparam              M_READ          = 3'b001;
   localparam              M_WRITE         = 3'b010;
   localparam              M_TRPUT         = 3'b011;
   //--------------------------------------------------------
   
   wire                         Clk_400;
   wire                         SoftReset;

   t_if_ccip_Tx                 af2cp_sTxPort_c;

  
   wire [ADDR_LMT-1:0]          ab2re_WrAddr;
   wire [15:0]                  ab2re_WrTID;
   wire [DATA_WIDTH -1:0]       ab2re_WrDin;
   wire                         ab2re_WrFence;
   wire                         ab2re_WrEn;

   wire                         re2ab_WrSent;
   wire                         re2ab_WrAlmFull;
   wire [ADDR_LMT-1:0]          ab2re_RdAddr;
   wire [15:0]                  ab2re_RdTID;
   wire                         ab2re_RdEn;

   wire                         re2ab_RdSent;
   wire                         re2ab_RdRspValid;
   wire                         re2ab_UMsgValid;
   wire                         re2ab_CfgValid;
   wire [15:0]                  re2ab_RdRsp;
   wire [DATA_WIDTH -1:0]       re2ab_RdData;
   wire                         re2ab_stallRd;
   wire                         re2ab_WrRspValid;
   wire [15:0]                  re2ab_WrRsp;
   wire                         re2xy_go;
   wire                         re2xy_Cont;
   wire [7:0]                   re2xy_test_cfg;
   wire [2:0]                   re2ab_Mode;
   wire                         ab2re_TestCmp;
  (* `KEEP_WIRE *) wire [255:0] ab2re_ErrorInfo;
   wire                         ab2re_ErrorValid;
   
   wire                         test_SoftReset;
   wire  [31:0]                 cr2re_inact_thresh;
   wire  [31:0]                 cr2re_interrupt0;
   wire  [63:0]                 cr2re_cfg;
   wire  [31:0]                 cr2re_ctl;
   wire  [63:0]                 cr2re_dsm_base;
   wire                         cr2re_dsm_base_valid;
   wire                         re2cr_wrlock_n;
   wire                         cr2s1_csr_write;
   
   wire  [9*64-1:0]             cr2xy_generic_config;

   logic                        ab2re_RdSop;
   logic [1:0]                  ab2re_WrLen;
   logic [1:0]                  ab2re_RdLen;
   logic                        ab2re_WrSop;

   logic                        re2ab_RdRspFormat;
   logic [1:0]                  re2ab_RdRspCLnum;
   logic                        re2ab_WrRspFormat;
   logic [1:0]                  re2ab_WrRspCLnum;
   logic [1:0]                  re2xy_multiCL_len;

   logic [31:0]                 re2cr_num_reads;
   logic [31:0]                 re2cr_num_writes;
   logic [31:0]                 re2cr_num_Rdpend;
   logic [31:0]                 re2cr_num_Wrpend;
   logic [31:0]                 re2cr_error;
   
   
   reg [31:0] afu_idle_counter;
   reg [31:0] ivp_idle_counter;

   reg                          SoftReset_q=1'b1;
   
   
   always @(posedge Clk_400)
   begin
       SoftReset_q <= SoftReset;
   end
   
requestor #(.PEND_THRESH(PEND_THRESH),
            .ADDR_LMT   (ADDR_LMT),
            .TXHDR_WIDTH(TXHDR_WIDTH),
            .RXHDR_WIDTH(RXHDR_WIDTH),
            .DATA_WIDTH (DATA_WIDTH )
            )
inst_requestor(


//      ---------------------------global signals-------------------------------------------------
       Clk_400               ,        //                       in    std_logic;  -- Core clock
       SoftReset_q            ,        //                       in    std_logic;  -- Use SPARINGLY only for control
//      ---------------------------CCI IF signals between CCI and requestor  ---------------------

       af2cp_sTxPort_c,
       cp2af_sRxPort,

       cr2re_inact_thresh,
       cr2re_interrupt0,
       cr2re_cfg,
       cr2re_ctl,
       cr2re_dsm_base,
       cr2re_dsm_base_valid,

       ab2re_WrAddr,                   // [ADDR_LMT-1:0]        arbiter:        Writes are guaranteed to be accepted
       ab2re_WrTID,                    // [15:0]                arbiter:        meta data
       ab2re_WrDin,                    // [DATA_WIDTH -1:0]     arbiter:        Cache line data
       ab2re_WrFence,                  //                       arbiter:        write fence
       ab2re_WrEn,                     //                       arbiter:        write enable
       re2ab_WrSent,                   //                       arbiter:        write issued
       re2ab_WrAlmFull,                //                       arbiter:        write fifo almost full
       
       ab2re_RdAddr,                   // [ADDR_LMT-1:0]        arbiter:        Reads may yield to writes
       ab2re_RdTID,                    // [15:0]                arbiter:        meta data
       ab2re_RdEn,                     //                       arbiter:        read enable
       re2ab_RdSent,                   //                       arbiter:        read issued

       re2ab_RdRspValid,               //                       arbiter:        read response valid
       re2ab_UMsgValid,                //                       arbiter:        UMsg valid
       re2ab_CfgValid,                 //                       arbiter:        Cfg Valid
       re2ab_RdRsp,                    // [ADDR_LMT-1:0]        arbiter:        read response header
       re2ab_RdData,                   // [DATA_WIDTH -1:0]     arbiter:        read data
       re2ab_stallRd,                  //                       arbiter:        stall read requests FOR LPBK1

       re2ab_WrRspValid,               //                       arbiter:        write response valid
       re2ab_WrRsp,                    // [ADDR_LMT-1:0]        arbiter:        write response header
       re2xy_go,                       //                       requestor:      start the test

       re2xy_Cont,                     //                       requestor:      continuous mode

       re2xy_test_cfg,                 // [7:0]                 requestor:      8-bit test cfg register.
       re2ab_Mode,                     // [2:0]                 requestor:      test mode
       
       ab2re_TestCmp,                  //                       arbiter:        Test completion flag
       ab2re_ErrorInfo,                // [255:0]               arbiter:        error information
       ab2re_ErrorValid,               //                       arbiter:        test has detected an error
       test_SoftReset,                 //                       requestor:      rest the app
       re2cr_wrlock_n,                 //                       requestor:      when low, block csr writes
       
       ab2re_RdLen,
       ab2re_RdSop,
       ab2re_WrLen,
       ab2re_WrSop,
           
       re2ab_RdRspFormat,
       re2ab_RdRspCLnum,
       re2ab_WrRspFormat,
       re2ab_WrRspCLnum,
       re2xy_multiCL_len,
       
       re2cr_num_reads,
       re2cr_num_writes,
       re2cr_num_Rdpend,
       re2cr_num_Wrpend,
       re2cr_error,
       
       ivp_idle_counter,
       afu_idle_counter

);

t_ccip_c0_ReqMmioHdr       cp2cr_MmioHdr;
logic                       cp2cr_MmioWrEn;
logic                       cp2cr_MmioRdEn;
t_ccip_mmioData             cp2cr_MmioDin; 
t_ccip_mmioData             cr2af_MmioDout;
logic                       cr2af_MmioDout_v;
t_ccip_c2_RspMmioHdr        cr2af_MmioHdr;
 
always_comb
begin
    cp2cr_MmioHdr        = t_ccip_c0_ReqMmioHdr'(cp2af_sRxPort.c0.hdr);
    cp2cr_MmioWrEn       = cp2af_sRxPort.c0.mmioWrValid;
    cp2cr_MmioRdEn       = cp2af_sRxPort.c0.mmioRdValid;
    cp2cr_MmioDin        = cp2af_sRxPort.c0.data[CCIP_MMIODATA_WIDTH-1:0];

    af2cp_sTxPort                  = af2cp_sTxPort_c;
    // Override the C2 channel
    af2cp_sTxPort.c2.hdr           = cr2af_MmioHdr;
    af2cp_sTxPort.c2.data          = cr2af_MmioDout;
    af2cp_sTxPort.c2.mmioRdValid   = cr2af_MmioDout_v;
end

accl_csr # (.CCIP_VERSION_NUMBER(CCIP_VERSION_NUMBER), .NEXT_DFH_BYTE_OFFSET(NEXT_DFH_BYTE_OFFSET))
inst_accl_csr (
    Clk_400,                       
    SoftReset_q,                   //  ACTIVE HIGH soft reset
    re2cr_wrlock_n,

    // MMIO Requests
    cp2cr_MmioHdr,
    cp2cr_MmioDin,  
    cp2cr_MmioWrEn,
    cp2cr_MmioRdEn,

    // MMIO Response
    cr2af_MmioHdr,  
    cr2af_MmioDout,   
    cr2af_MmioDout_v,

    cr2re_inact_thresh,
    cr2re_interrupt0,
    cr2re_cfg,
    cr2re_ctl,
    cr2re_dsm_base,
    cr2re_dsm_base_valid,
    cr2s1_csr_write,

    cr2xy_generic_config,

    re2cr_num_reads,
    re2cr_num_writes,
    re2cr_num_Rdpend,
    re2cr_num_Wrpend,
    re2cr_error
);

wire acc_clk;
wire acc_rst;
// Modify this size for the custom config
wire [9*64-1:0] acc_config;
wire acc_start;
wire acc_done;
reg spl_rd_req_ready;
reg spl_rd_req_ready_e;
wire spl_rd_req_valid;
wire [8:0] spl_rd_req_tag;
wire [6:0] spl_rd_req_ioid;
wire [63:0] spl_rd_req_addr;

wire spl_rd_resp_ready;
wire spl_rd_resp_ready_const1;
reg spl_rd_resp_valid;
reg [8:0] spl_rd_resp_tag;
reg [6:0] spl_rd_resp_ioid;
reg [511:0] spl_rd_resp_data;

reg spl_wr_req_ready;
reg spl_wr_req_ready_e;
wire spl_wr_req_valid;

wire [8:0] spl_wr_req_tag;
wire [6:0] spl_wr_req_width;
wire [6:0] spl_wr_req_offset;
wire [6:0] spl_wr_req_ioid;
wire [511:0] spl_wr_req_data;
wire [63:0] spl_wr_req_addr;

wire spl_wr_resp_ready;
wire spl_wr_resp_valid;
wire [8:0] spl_wr_resp_tag;
wire spl_wr_resp_ack;
wire afu_req_idle;

/*
 * Mocking returns from the arbiter
 */
/* Not hooked up
       re2ab_WrRspValid,               //                       arbiter:           write response valid
       re2ab_WrRsp,                    // [ADDR_LMT-1:0]        arbiter:           write response header
 */
 
 reg spl_wr_req_ready0;
 reg spl_rd_req_ready0;

 logic [31:0] ivp_idle_counter_p1;
 logic [31:0] ivp_idle_counter_m1;
 logic [31:0] afu_idle_counter_p1;
 logic [31:0] afu_idle_counter_m1;

 logic re2xy_go_delayed;
 logic ivp_req_ready_delayed;
 logic ivp_req_valid_delayed;
 logic afu_req_ready_delayed;
 logic afu_req_valid_delayed;

   always_comb
   begin
       ivp_idle_counter_p1 = ivp_idle_counter + 1'b1;   
       ivp_idle_counter_m1 = ivp_idle_counter - 1'b1;   
       afu_idle_counter_p1 = afu_idle_counter + 1'b1;   
       afu_idle_counter_m1 = afu_idle_counter - 1'b1;   
   end

   always @(posedge Clk_400)
   begin
      re2xy_go_delayed <= re2xy_go;
      ivp_req_ready_delayed <= ivp_req_ready;
      ivp_req_valid_delayed <= ivp_req_valid;
      afu_req_ready_delayed <= !cp2af_sRxPort.c1TxAlmFull;
      afu_req_valid_delayed <= af2cp_sTxPort.c1.valid;

      if (re2xy_go_delayed &  ivp_req_ready_delayed & !ivp_req_valid_delayed) begin
         ivp_idle_counter <= ivp_idle_counter_p1;
      end
      if (re2xy_go_delayed & !ivp_req_ready_delayed &  ivp_req_valid_delayed) begin
         ivp_idle_counter <= ivp_idle_counter_m1;
      end

      if (re2xy_go_delayed &  afu_req_ready_delayed & !afu_req_valid_delayed) begin
         afu_idle_counter <= afu_idle_counter_p1;
      end
      if (re2xy_go_delayed & !afu_req_ready_delayed &  afu_req_valid_delayed) begin
         afu_idle_counter <= afu_idle_counter_m1;
      end

      if (SoftReset == 1'b1) begin
         ivp_idle_counter <= 32'b0;
         afu_idle_counter <= 32'b0;
         ivp_req_ready_delayed <= 1'b0;
         ivp_req_valid_delayed <= 1'b0;
         afu_req_ready_delayed <= 1'b0;
         afu_req_valid_delayed <= 1'b0;
      end
   end


   always @(posedge Clk_400)
   begin
        if (spl_rd_resp_ready == 1'b0) begin
          $display(
          "Warning: Async FIFOs got full and back pressure is not handled in the requestor %m @ time %0d:\n", $time);
          $stop(1);
        end
        spl_wr_req_ready0 <= !cp2af_sRxPort.c1TxAlmFull;
        spl_wr_req_ready  <= spl_wr_req_ready0;
        //spl_rd_req_ready  <= !cp2af_sRxPort.c0TxAlmFull;
        spl_rd_req_ready0  <= !cp2af_sRxPort.c0TxAlmFull;
        spl_rd_req_ready  <= spl_rd_req_ready0;
        spl_rd_resp_valid <= re2ab_RdRspValid;
        spl_rd_resp_tag <= re2ab_RdRsp[15:7];
        spl_rd_resp_ioid <= re2ab_RdRsp[6:0];
        spl_rd_resp_data <= re2ab_RdData;
   end

assign afu_req_idle = !spl_rd_req_ready&spl_rd_req_valid;

assign ab2re_WrAddr = spl_wr_req_addr >> 6;
assign ab2re_WrTID = { spl_wr_req_tag, spl_wr_req_ioid};
assign ab2re_WrDin = spl_wr_req_data;
assign ab2re_WrFence = 1'b0;
assign ab2re_WrEn = spl_wr_req_valid && spl_wr_req_ready;
//assign spl_wr_req_ready  = !cp2af_sRxPort.c1TxAlmFull;

assign ab2re_RdAddr = spl_rd_req_addr >> 6;
assign ab2re_RdTID = { spl_rd_req_tag, spl_rd_req_ioid}; // 6 bits and 7 bits
assign ab2re_RdEn = spl_rd_req_valid && spl_rd_req_ready;

//assign spl_rd_req_ready  = !cp2af_sRxPort.c0TxAlmFull;
//assign spl_rd_resp_valid = re2ab_RdRspValid;
//assign spl_rd_resp_tag = re2ab_RdRsp[15:7];
//assign spl_rd_resp_ioid = re2ab_RdRsp[6:0];
//assign spl_rd_resp_data = re2ab_RdData;

assign ab2re_TestCmp = acc_done;
assign ab2re_ErrorInfo = 0;
assign ab2re_ErrorValid = 1'b0;

assign ab2re_RdLen = 0;
assign ab2re_RdSop = 1'b1;
assign ab2re_WrLen = 0;
assign ab2re_WrSop = 1'b1;


assign acc_clk = (ACC_CLK == CLK_400) ? Clk_400      : 
                 (ACC_CLK == CLK_273) ? uClk_usr     :
                 (ACC_CLK == CLK_200) ? pClkDiv2     : 
                 (ACC_CLK == CLK_136) ? uClk_usrDiv2 :
                                        pClkDiv4; 
assign acc_rst = test_SoftReset; // negative logic

// Modify this size for the custom config
assign acc_config = cr2xy_generic_config[ 0 +: 9*64]; 
assign acc_start = re2xy_go;

/*
 *
 * spl_wr_resp_* signals are stubbed out
 *
 */
assign spl_wr_resp_valid = 1'b0;
assign spl_wr_resp_tag = 9'b0;
assign spl_wr_resp_ack = 1'b0;

//the verstion from high-level synthesis (sometimes wrapped with an arbiter if accelerator is multi-channel)
hld_shim_wrapper
#(
    .RD_PORTS (`HLD_MEM_RD_PORTS),
    .WR_PORTS (`HLD_MEM_WR_PORTS),
    .FIFO_REQ_DEPTH_LOG2 (`HLD_REQ_ASYNC_FIFO_LOG2DEPTH),
    .FIFO_RESP_DEPTH_LOG2 (`HLD_RESP_ASYNC_FIFO_LOG2DEPTH)
)
hld_shim_inst(  .a_clk(acc_clk),
            .clk( Clk_400),
            .rst(acc_rst),
            .config_(acc_config),
            .start(acc_start),
            .done(acc_done),
            .spl_rd_req_ready(spl_rd_req_ready), 
            .spl_rd_req_valid(spl_rd_req_valid),
            .spl_rd_req_data({spl_rd_req_tag,spl_rd_req_ioid,spl_rd_req_addr}),

            .spl_rd_resp_ready(spl_rd_resp_ready),  
            .spl_rd_resp_valid(spl_rd_resp_valid),
            .spl_rd_resp_data({spl_rd_resp_tag,spl_rd_resp_ioid,spl_rd_resp_data}),

            .spl_wr_req_ready(spl_wr_req_ready),
            .spl_wr_req_valid(spl_wr_req_valid),
            .spl_wr_req_data({spl_wr_req_tag,spl_wr_req_width,spl_wr_req_offset,spl_wr_req_ioid,spl_wr_req_data,spl_wr_req_addr}),

            .spl_wr_resp_ready(spl_wr_resp_ready),
            .spl_wr_resp_valid(spl_wr_resp_valid),
            .spl_wr_resp_data({spl_wr_resp_tag,7'b0,spl_wr_resp_ack})
          );



endmodule
