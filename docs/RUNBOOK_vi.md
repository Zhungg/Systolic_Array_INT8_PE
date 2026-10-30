# Runbook 10 giờ: sa_top 8×8 INT8, RTL → GDSII (gpdk045, 200 MHz)

Mọi lệnh chạy trên máy `infect`, trong thư mục `/home/icer/projects/sa_int8_45nm`.
Mỗi bước có **dấu hiệu đạt** để kiểm tra, và nêu rõ **cần gửi lại gì** khi gặp lỗi.

```bash
cd /home/icer/projects && tar xzf sa_int8_45nm_v1.0.tar.gz && cd sa_int8_45nm
chmod +x */*.sh physical_design/run_pnr.sh flow_config.sh
```

| # | Giờ (dự kiến) | Bước | Lệnh | Đạt khi |
|---|---|---|---|---|
| 1 | 0:00–0:20 | RTL sim + coverage | `cd simulation && ./run_rtl.sh` | `*** TEST PASSED ***`, `load/compute overlap` > 0 |
| 2 | 0:20–0:30 | Coverage | `imc -load cov_work/scope/sa_selfcheck &` (VNC) | Block/expression gần 100% (chụp ảnh lại cho README) |
| 3 | 0:30–1:15 | Synthesis + DFT | `cd synthesis && ./run_synth_dft.sh` | `RESULT: GENUS_DFT_SCRIPT_COMPLETED`, `OAI32X1_INSTANCES = 0`. **Điểm quyết định:** nếu WNS trong `dft_run/reports/post_dft_timing.rpt` < +0,3 ns, đặt `MAC_PIPE = 1` trong `rtl/sa_top.v` rồi chạy lại bước 1 và 3 (xem `docs/PD_PLAN_vi.md`) |
| 4 | 1:15–1:30 | GLS sau synthesis | `cd simulation && ./run_gls.sh syn` | `TEST PASSED` |
| 5 | 1:30–2:00 | ATPG | `cd synthesis && ./run_atpg.sh` | Test coverage > 99% |
| 6 | 2:00–2:15 | LEC RTL ↔ DFT | `cd equivalence_checking && ./run_lec.sh` | `Equivalent`, 0 non-equivalent |
| 7 | 2:15–6:00 | Innovus | `cd physical_design && ./run_pnr.sh 01` … `07` | Xem bảng dưới |
| 7b | 6:00–6:20 | Voltus IR drop | `./run_pnr.sh 08` | VDD drop và VSS bounce < 45 mV, 0 vi phạm |
| 8 | 6:00–7:30 | Assura DRC/LVS (máy ảo 2) | `results/sa_top_final.gds` + `results/sa_top_postroute_pg.v` | DRC 0, LVS match |
| 9 | 7:30–10:00 | Dự phòng, GLS/LEC sau PnR (nếu còn giờ), README | `./run_gls.sh route` rồi `./run_gls.sh route sdf slow` / `fast` | Chạy zero-delay trước (đối chứng), xem dòng `TEST PASSED`, không dựa vào exit code |

## Kiểm tra sau từng bước Innovus

Nên chạy **từng bước một** (`./run_pnr.sh 01`, rồi `02`…), không chạy `all` ở lần đầu.

| Bước | Xem | Đạt khi |
|---|---|---|
| 01 init | `logs/01_init.log` | `INSTANCES = …` (~40–50 nghìn), có `DONT_USE OAI32X1 = true` |
| 02 floorplan | Các dòng `PINS left=66 top=66 bottom=257 right=19` và `CORE = … ; pin pitch …` | Không có lỗi `edit_pin`; lõi khoảng 375–420 µm |
| 03 power | `reports/physical_verification/pg_connectivity_after_powerplan.rpt` | Không có open/dangling |
| 04 place | `reports/timing/1_place_opt/` (`*.summary`, `congestion.rpt`) | WNS ≥ 0 (pre-CTS), overflow < 1% |
| 05 cts | `reports/timing/2_post_cts/`, `reports/clock_tree/post_cts/` | Setup WNS ≥ 0, **hold WNS ≥ 0**, skew < 100 ps |
| 06 route | `reports/timing/3_post_route/` | Setup/hold ≥ 0, DRV = 0 |
| 07 finish | `reports/physical_verification/`, `power/`, `routing/`, `clock_tree/post_route/`, `timing/4_signoff/` | DRC 0, connectivity sạch, `OAI32X1_INSTANCES = 0`, có `TOTAL_POWER_mW`, có file GDS |
| 08 rail | `reports/rail_analysis/static_25c/` | Có dòng `PADS VDD = 2` (hoặc nhiều hơn), drop < 45 mV |

Cấu trúc thư mục `reports/` giống `ALU_32b/physical_design/signoff/`, nên khi viết README có thể chép sang `signoff/` theo đúng cách của repo ALU.

**Khi một bước lỗi:** gửi mình `grep -n -i "error" logs/<bước>.log | head -40` kèm khoảng 30 dòng cuối của log. Sau khi sửa script, chạy lại đúng bước đó, vì mỗi bước tự đọc database của bước trước.

**Thời gian chạy ước tính** (4 nhân, khoảng 45 nghìn cell): 01–03 khoảng 5 phút, 04 khoảng 15 phút, 05 khoảng 15–20 phút, 06 khoảng 30–45 phút, 07 khoảng 10 phút.

**Lý do chọn từng con số PD:** xem `docs/PD_PLAN_vi.md`.

**Phương án dự phòng thời gian:** nếu đến giờ thứ 5 mà timing 200 MHz vẫn chưa đạt, sửa `-period 5.0` thành `6.67` (150 MHz) trong `constraints/sa_top_func.sdc` rồi chạy lại từ bước 04. Phương án cuối cùng là đổi `N=4` trong RTL (khoảng 12 nghìn cell).

## Assura (máy ảo 2): giống quy trình của dự án ALU_32b
- GDS: `physical_design/results/sa_top_final.gds`, đã merge `gsclib045.gds` và dùng map `streamOut_gpdk045_assura_lvs.map` (nhãn chân ở datatype 0 để Assura đọc được, giống ALU_32b).
- Netlist cho LVS: `physical_design/results/sa_top_postroute_pg.v` (có chân PG), import thành schematic như lần trước.
- Thiết kế lớn hơn ALU khoảng 50 lần, nên Assura LVS sẽ mất 10–30 phút.

## Bài học từ ALU32 (handover ngày 30/10) đã đưa vào bản v1.0

| Vấn đề ở ALU32 | Đã xử lý trong v1.0 |
|---|---|
| LVS bằng netlist thường bị lệch VDD/VSS; chỉ khớp khi dùng netlist có chân nguồn | `07_finish.tcl` xuất `sa_top_postroute_pg.v` bằng `saveNetlist -phys -includePowerGround` (đúng lệnh đã khớp ở ALU), rồi in số kết nối `.VDD(` và `.VSS(` để kiểm |
| SDF trộn 2 view trong 1 file sinh bộ ba `(0.085:0.000:0.000)`; GLS có SDF FAIL 1.029 lỗi | Mỗi file SDF chỉ chứa 1 view (`_slow.sdf` / `_fast.sdf`), giữ nguyên các option `write_sdf` đã chạy được |
| `xrun` trả exit code 0 dù testbench FAIL | `run_gls.sh` lấy kết quả từ dòng `TEST PASSED/FAILED`, mỗi lần chạy dùng thư mục riêng có link `dut.sdf` |
| Thiếu license Tempus signoff (`Tempus_Timing_Signoff_XL/L`, FlexNet -5,357) | Không dùng Tempus độc lập; timing signoff lấy từ `time_design` và `report_timing_summary` trong Innovus (`reports/timing/4_signoff`) |
| Có sẵn cảnh báo SDF `RECREM` ↔ cell model không có `$recrem` | Đây là cảnh báo đã biết; khi tổng hợp kết quả GLS có SDF, ghi rõ số cảnh báo này |
| EM / dynamic IR chưa đủ điều kiện để signoff | Bước 08 chỉ chạy IR tĩnh, ghi rõ trong README là chưa signoff EM |
