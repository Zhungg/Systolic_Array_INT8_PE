# Quy hoạch physical design: nguồn gốc từng con số

Mỗi con số được đánh dấu theo nguồn gốc:
- **[ALU]**: lấy từ ALU_32b, đã chạy được trên máy bạn.
- **[TÍNH]**: suy ra từ ước lượng có công thức.
- **[GIẢ ĐỊNH]**: chọn theo kinh nghiệm, cần kiểm lại bằng tool.

## 1. Kích thước
| Thông số | Giá trị | Nguồn gốc |
|---|---|---|
| Diện tích cell | ~103.000 µm², 45 nghìn cell, 4.441 flop | **[TÍNH]** Yosys trên gsclib045 slow. Genus thường cho số nhỏ hơn 10–20% |
| Utilization ban đầu | 0,60 | **[TÍNH]** ALU đặt 0,70 nhưng kết thúc ở 80,7% (tăng 10,7 điểm do CTS, buffer sửa hold và tối ưu). Với mức tăng tương tự, 0,60 sẽ kết thúc quanh 70%. Mảng systolic có nhiều đường cần sửa hold hơn nên cần dư chỗ hơn |
| Lõi | ~375–420 µm mỗi cạnh, tỉ lệ 1:1 | **[TÍNH]** = √(diện tích / 0,6) |
| Lề lõi | 6 µm | **[TÍNH]** ring = offset 0,5 + 2 × 2,0 + spacing 0,5 = 5,0 µm, cộng 1 µm dư |

## 2. Chân I/O
| Cạnh | Nội dung | Số chân | Lớp |
|---|---|---|---|
| Trái | a_in, a_valid, a_bank | 66 | Metal3 (ngang) |
| Trên | w_in, w_load, w_bank | 66 | Metal4 (dọc) |
| Dưới | c_out, c_valid | 257 | Metal4 (dọc) |
| Phải | clk, rst_n, SE, scan_in_0..7, scan_out_0..7 | 19 | Metal3 (ngang) |

- **Hướng chân theo dòng dữ liệu** của mảng: activation chạy từ trái sang phải, trọng số từ trên xuống, tổng riêng phần (partial sum) ra ở dưới. Nhờ vậy dây ngắn nhất. **[TÍNH]**
- **Lớp kim loại theo chiều ưu tiên:** cạnh trái/phải dùng lớp ngang, cạnh trên/dưới dùng lớp dọc. Lưu ý ALU đã đặt Metal4 cho cạnh trái và vẫn chạy được, nhưng dùng đúng chiều ưu tiên thì router dễ đi dây hơn.
- **Khoảng cách chân** được **tính lúc chạy** từ kích thước lõi thật: rải trên 80% chiều dài cạnh, bắt vào lưới track 0,2 µm, tối thiểu 1,0 µm. Với lõi 410 µm, khoảng cách lần lượt khoảng 4,8 / 4,8 / 1,2 / 17 µm. Nếu cạnh dưới không đủ chỗ cho 257 chân, script dừng và báo lỗi.

## 3. Mạng nguồn (power grid)
| Thông số | Giá trị | Nguồn gốc |
|---|---|---|
| Ước lượng công suất | ~7 mW; thiết kế lưới cho 20 mW | **[TÍNH]** ALU đo được 0,076 mW ở 2.302 µm² và 100 MHz, activity 0,2. Nhân tỉ lệ diện tích (×44,7) và tần số (×2) được 6,8 mW. Datapath MAC đảo bit nhiều hơn nên nhân thêm khoảng 3 lần làm dự phòng |
| Dòng điện | ~8 mA danh định, 22 mA thiết kế (0,9 V) | **[TÍNH]** |
| Ring | Metal11 trên/dưới, Metal10 trái/phải, rộng 2,0 µm, spacing 0,5 µm | Lớp kim loại **[ALU]**; độ rộng **[GIẢ ĐỊNH]**, gấp khoảng 3 lần ALU (0,7 µm) vì dòng lớn hơn khoảng 100 lần nhưng chu vi ring cũng dài hơn khoảng 6 lần |
| Stripe | Metal10 dọc, 1,0 µm, mỗi 20 µm | Lệnh **[ALU]**. Mật độ kim loại 10%, tương đương ALU (2 × 0,3 / 5 = 12%) |
| Follow-pin | Metal1, nối lên stripe | Lệnh **[ALU]** |
| Mục tiêu IR drop | < 5% VDD = 45 mV | **[GIẢ ĐỊNH]** theo mức thông dụng. **Cần kiểm bằng Voltus** như bạn đã làm với ALU |
| Giới hạn EM của Metal10/11 | — | **Chưa biết**: phụ thuộc rule của gpdk045. Kiểm bằng Voltus EM; nếu vi phạm thì tăng độ rộng ring hoặc giảm bước stripe xuống 15 µm |

## 4. Timing
| Thông số | Giá trị | Nguồn gốc |
|---|---|---|
| Clock | 5 ns (200 MHz); uncertainty setup 0,15 / hold 0,05 ns | Do bạn chốt; uncertainty là **[GIẢ ĐỊNH]** (3% chu kỳ) |
| I/O delay | max 1,0 ns (20% chu kỳ), min 0,5 ns | Tỉ lệ 20% **[ALU]** |
| Đường găng | PE: nhân 8×8 rồi cộng 32 bit trong 1 chu kỳ | **Rủi ro chính.** Slack +1,5 ns của ALU ở 10 ns **không** cho biết tốc độ thật, vì khi timing dễ thì Genus ưu tiên tối ưu diện tích |
| Điểm quyết định | Sau bước 3 (Genus), xem WNS trong `post_dft_timing.rpt` | WNS < +0,3 ns thì đặt **`MAC_PIPE = 1`** trong `rtl/sa_top.v` (thêm thanh ghi tích, mỗi PE thêm 16 flop, độ trễ tăng 1 chu kỳ), rồi chạy lại từ bước 3. Đã kiểm: testbench pass với cả hai chế độ |
| Max transition của clock | 0,15 ns | **[GIẢ ĐỊNH]** 3% chu kỳ. Thư viện cho phép tối đa 0,28 ns |
| Insertion delay của clock | dự đoán 0,5–0,8 ns cho 4.400 sink | **[GIẢ ĐỊNH]**. Khi lớn hơn min input delay (0,5 ns), các flop ngõ vào sẽ cần buffer sửa hold. Đây là hiện tượng bình thường |
| Hold trên chuỗi scan | Khoảng 4.400 đường Q→SI rất ngắn | Hold sẽ là phần việc chính ở SCAN_HOLD_VIEW; đã có `opt_design -hold` sau CTS và sau route |

## 5. Dự kiến kết quả để đối chiếu
- Sau bước 04 (place): mật độ khoảng 60–62%, congestion overflow < 1%.
- Sau bước 05 (CTS): khoảng vài trăm buffer clock; skew < 100 ps.
- Sau bước 06 (route): mật độ khoảng 68–72%, DRV = 0, setup và hold ≥ 0 trên cả 4 view.

Nếu số thực tế lệch nhiều so với các mốc này, đó chính là thông tin cần gửi lại để điều chỉnh.
