//********************************************************************************
// SPDX-License-Identifier: Apache-2.0
//
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//********************************************************************************

initial begin
//https://dev.azure.com/ms-tsd/SCIPS_IP/_workitems/edit/1196970    $assertoff(0, caliptra_ss_top_tb.caliptra_ss_dut.i3c.i3c.xhci.i3c_csr.ERR_HWIF_IN); // FIXME - remove https://github.com/chipsalliance/i3c-core/issues/22

  // https://github.com/chipsalliance/caliptra-ss/issues/1115
  // keccak_complete_i gets high during 13th clock cycle after keccak_run_o, but assertion expects it after 24th cycle
  $assertoff(0, caliptra_ss_top_tb.caliptra_ss_dut.caliptra_top_dut.mldsa.sampler_top_inst.sha3_inst.u_pad.RunThenComplete_M);
  // Exiting prod debug triggers this assertion
  $assertoff(0, `MCI_PATH.LCC_state_translator.NonDebugUnlockedCheck_A);
end
