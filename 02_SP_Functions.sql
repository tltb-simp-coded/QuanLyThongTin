-- ============================================================
-- FILE    : SP_Functions.sql
-- MÔN     : IE103.Q22 - Quản lý Thông tin
-- ĐỀ TÀI : Hệ thống Quản lý Bệnh viện
-- PHẦN    : Stored Procedures + Functions
-- THỰC HIỆN: Trần Lê Thiên Bảo
-- ============================================================

-- Đổi tên CSDL cho đúng với tên bạn đã tạo trong SSMS
USE QuanLyBenhVien;
GO

-- ============================================================
-- PHẦN 1: STORED PROCEDURES
-- ============================================================


-- ============================================================
-- SP 1: sp_TiepNhanBenhMoi
-- Mục đích : Tiếp nhận bệnh nhân (mới hoặc cũ) và tạo lịch hẹn
-- Input    :
--   @CCCD        — CCCD bệnh nhân (dùng để nhận diện bệnh nhân cũ/mới)
--   @HoTen       — Họ tên        (bắt buộc nếu bệnh nhân mới)
--   @NgaySinh    — Ngày sinh     (bắt buộc nếu bệnh nhân mới)
--   @GioiTinh    — Nam / Nữ / Khác
--   @DiaChi      — Địa chỉ
--   @SDT         — Số điện thoại
--   @NhomMau     — Nhóm máu
--   @TienSuBenh  — Tiền sử bệnh
--   @MaBS        — Mã bác sĩ tiếp nhận
--   @NgayGio     — Thời gian khám
--   @LyDoKham    — Lý do khám
-- Output   :
--   @MaBN_Out    — Mã bệnh nhân (cũ hoặc mới được tạo)
--   @MaLich_Out  — Mã lịch hẹn vừa tạo
-- ============================================================
CREATE OR ALTER PROCEDURE sp_TiepNhanBenhMoi
    @CCCD        VARCHAR(20),
    @HoTen       NVARCHAR(100) = NULL,
    @NgaySinh    DATE          = NULL,
    @GioiTinh    NVARCHAR(10)  = NULL,
    @DiaChi      NVARCHAR(255) = NULL,
    @SDT         VARCHAR(15)   = NULL,
    @NhomMau     VARCHAR(5)    = NULL,
    @TienSuBenh  NVARCHAR(MAX) = NULL,
    @MaBS        VARCHAR(20),
    @NgayGio     DATETIME,
    @LyDoKham    NVARCHAR(255) = NULL,
    @MaBN_Out    VARCHAR(20)   OUTPUT,
    @MaLich_Out  VARCHAR(20)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @MaBN    VARCHAR(20);
        DECLARE @MaLich  VARCHAR(20);
        DECLARE @SoThuTu INT;

        -- Bước 1: Kiểm tra bệnh nhân đã có trong hệ thống chưa (qua CCCD)
        SELECT @MaBN = MaBN
        FROM BenhNhan
        WHERE CCCD = @CCCD;

        IF @MaBN IS NULL
        BEGIN
            -- Bệnh nhân mới → Kiểm tra thông tin bắt buộc
            IF @HoTen IS NULL OR @NgaySinh IS NULL
            BEGIN
                RAISERROR(N'Lỗi: HoTen và NgaySinh là bắt buộc khi tạo bệnh nhân mới!', 16, 1);
                ROLLBACK TRANSACTION; RETURN;
            END

            -- Tự động sinh MaBN theo định dạng BN001, BN002, ...
            SELECT @SoThuTu = ISNULL(
                MAX(CAST(SUBSTRING(MaBN, 3, LEN(MaBN)) AS INT)), 0
            ) + 1
            FROM BenhNhan
            WHERE MaBN LIKE 'BN%'
              AND ISNUMERIC(SUBSTRING(MaBN, 3, LEN(MaBN))) = 1;

            SET @MaBN = 'BN' + RIGHT('000' + CAST(@SoThuTu AS VARCHAR), 3);

            INSERT INTO BenhNhan (MaBN, HoTen, NgaySinh, GioiTinh, CCCD, DiaChi, SDT, NhomMau, TienSuBenh)
            VALUES (@MaBN, @HoTen, @NgaySinh, @GioiTinh, @CCCD, @DiaChi, @SDT, @NhomMau, @TienSuBenh);

            PRINT N'Đã tạo hồ sơ bệnh nhân mới: ' + @MaBN + N' - ' + @HoTen;
        END
        ELSE
        BEGIN
            PRINT N'Bệnh nhân đã có trong hệ thống. Mã BN: ' + @MaBN;
        END

        -- Bước 2: Kiểm tra bác sĩ tồn tại
        IF NOT EXISTS (SELECT 1 FROM BacSi WHERE MaBS = @MaBS)
        BEGIN
            RAISERROR(N'Lỗi: Mã bác sĩ không tồn tại trong hệ thống!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 3: Tạo lịch hẹn, sinh MaLich tự động
        SELECT @SoThuTu = ISNULL(
            MAX(CAST(SUBSTRING(MaLich, 3, LEN(MaLich)) AS INT)), 0
        ) + 1
        FROM LichHen
        WHERE MaLich LIKE 'LH%'
          AND ISNUMERIC(SUBSTRING(MaLich, 3, LEN(MaLich))) = 1;

        SET @MaLich = 'LH' + RIGHT('000' + CAST(@SoThuTu AS VARCHAR), 3);

        INSERT INTO LichHen (MaLich, MaBN, MaBS, NgayGio, LyDoKham, TrangThai)
        VALUES (@MaLich, @MaBN, @MaBS, @NgayGio, @LyDoKham, N'Chờ khám');

        -- Trả kết quả
        SET @MaBN_Out   = @MaBN;
        SET @MaLich_Out = @MaLich;

        PRINT N'Đã tạo lịch hẹn: ' + @MaLich
            + N' | Bệnh nhân: ' + @MaBN
            + N' | Thời gian: ' + CONVERT(VARCHAR, @NgayGio, 120);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Err1 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err1, 16, 1);
    END CATCH
END;
GO


-- ============================================================
-- Table Type dùng cho sp_KeDonThuoc
-- Định nghĩa kiểu bảng chứa danh sách thuốc truyền vào SP
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.types WHERE name = 'DanhSachThuocType')
BEGIN
    CREATE TYPE DanhSachThuocType AS TABLE (
        MaThuoc  VARCHAR(20)    NOT NULL,
        SoLuong  INT            NOT NULL,
        LieuDung NVARCHAR(100)  NULL,
        TanSuat  NVARCHAR(100)  NULL
    );
END
GO


-- ============================================================
-- SP 2: sp_KeDonThuoc
-- Mục đích : Kê đơn thuốc cho một hồ sơ bệnh án.
--            Kiểm tra tồn kho và hạn dùng, tự động trừ kho sau khi kê.
-- Input    :
--   @MaHoSo         — Mã hồ sơ bệnh án
--   @MaNV_KeDon     — Mã nhân viên kê đơn (phải có VaiTro = 'Bác sĩ')
--   @HuongDanSuDung — Hướng dẫn sử dụng chung cho đơn
--   @DanhSachThuoc  — Danh sách thuốc (TVP: MaThuoc, SoLuong, LieuDung, TanSuat)
-- Output   :
--   @MaDon_Out      — Mã đơn thuốc vừa tạo
-- ============================================================
CREATE OR ALTER PROCEDURE sp_KeDonThuoc
    @MaHoSo         VARCHAR(20),
    @MaNV_KeDon     VARCHAR(20),
    @HuongDanSuDung NVARCHAR(MAX) = NULL,
    @DanhSachThuoc  DanhSachThuocType READONLY,
    @MaDon_Out      VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @MaDon   VARCHAR(20);
        DECLARE @SoThuTu INT;

        -- Bước 1: Kiểm tra hồ sơ bệnh án tồn tại
        IF NOT EXISTS (SELECT 1 FROM HoSoBenhAn WHERE MaHoSo = @MaHoSo)
        BEGIN
            RAISERROR(N'Lỗi: Mã hồ sơ bệnh án không tồn tại!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 2: Kiểm tra nhân viên kê đơn phải là Bác sĩ
        IF NOT EXISTS (
            SELECT 1 FROM NhanVien
            WHERE MaNV = @MaNV_KeDon AND VaiTro = N'Bác sĩ'
        )
        BEGIN
            RAISERROR(N'Lỗi: Nhân viên kê đơn không có vai trò Bác sĩ!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 3: Danh sách thuốc không được rỗng
        IF NOT EXISTS (SELECT 1 FROM @DanhSachThuoc)
        BEGIN
            RAISERROR(N'Lỗi: Danh sách thuốc không được rỗng!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 4: Kiểm tra tất cả thuốc trong kho có đủ số lượng không
        IF EXISTS (
            SELECT 1
            FROM @DanhSachThuoc ds
            JOIN Thuoc t ON ds.MaThuoc = t.MaThuoc
            WHERE t.SoLuongTon < ds.SoLuong
        )
        BEGIN
            RAISERROR(N'Lỗi: Một hoặc nhiều thuốc không đủ số lượng trong kho!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 5: Kiểm tra hạn sử dụng (Trigger cũng xử lý nhưng báo lỗi ở đây rõ hơn)
        IF EXISTS (
            SELECT 1
            FROM @DanhSachThuoc ds
            JOIN Thuoc t ON ds.MaThuoc = t.MaThuoc
            WHERE t.HanSuDung <= CAST(GETDATE() AS DATE)
        )
        BEGIN
            RAISERROR(N'Lỗi: Một hoặc nhiều thuốc trong đơn đã hết hạn sử dụng!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 6: Sinh MaDon tự động (DT001, DT002, ...)
        SELECT @SoThuTu = ISNULL(
            MAX(CAST(SUBSTRING(MaDon, 3, LEN(MaDon)) AS INT)), 0
        ) + 1
        FROM DonThuoc
        WHERE MaDon LIKE 'DT%'
          AND ISNUMERIC(SUBSTRING(MaDon, 3, LEN(MaDon))) = 1;

        SET @MaDon = 'DT' + RIGHT('000' + CAST(@SoThuTu AS VARCHAR), 3);

        -- Bước 7: Tạo đơn thuốc (header)
        INSERT INTO DonThuoc (MaDon, MaHoSo, MaNV_KeDon, NgayKe, HuongDanSuDung)
        VALUES (@MaDon, @MaHoSo, @MaNV_KeDon, GETDATE(), @HuongDanSuDung);

        -- Bước 8: Thêm chi tiết từng loại thuốc vào đơn
        INSERT INTO ChiTietDonThuoc (MaDon, MaThuoc, SoLuong, LieuDung, TanSuat)
        SELECT @MaDon, MaThuoc, SoLuong, LieuDung, TanSuat
        FROM @DanhSachThuoc;

        -- Bước 9: Tự động trừ số lượng tồn kho
        UPDATE t
        SET t.SoLuongTon = t.SoLuongTon - ds.SoLuong
        FROM Thuoc t
        JOIN @DanhSachThuoc ds ON t.MaThuoc = ds.MaThuoc;

        SET @MaDon_Out = @MaDon;

        PRINT N'Đã tạo đơn thuốc: ' + @MaDon + N' cho hồ sơ ' + @MaHoSo;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Err2 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err2, 16, 1);
    END CATCH
END;
GO


-- ============================================================
-- SP 3: sp_XuatHoaDon
-- Mục đích : Tính tổng tiền và tạo hóa đơn cho một hồ sơ bệnh án
-- Input    :
--   @MaHoSo       — Mã hồ sơ bệnh án
-- Output   :
--   @MaHD_Out     — Mã hóa đơn vừa tạo
--   @TongTien_Out — Tổng số tiền cần thanh toán
-- ============================================================
CREATE OR ALTER PROCEDURE sp_XuatHoaDon
    @MaHoSo       VARCHAR(20),
    @MaHD_Out     VARCHAR(20)    OUTPUT,
    @TongTien_Out DECIMAL(18, 2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @MaHD     VARCHAR(20);
        DECLARE @MaBN     VARCHAR(20);
        DECLARE @TongTien DECIMAL(18, 2);
        DECLARE @SoThuTu  INT;

        -- Bước 1: Kiểm tra hồ sơ bệnh án tồn tại
        SELECT @MaBN = MaBN
        FROM HoSoBenhAn
        WHERE MaHoSo = @MaHoSo;

        IF @MaBN IS NULL
        BEGIN
            RAISERROR(N'Lỗi: Hồ sơ bệnh án không tồn tại!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 2: Kiểm tra hóa đơn chưa được tạo trước đó (tránh trùng)
        IF EXISTS (SELECT 1 FROM HoaDon WHERE MaHoSo = @MaHoSo)
        BEGIN
            RAISERROR(N'Lỗi: Hóa đơn cho hồ sơ này đã tồn tại, không thể tạo lại!', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        -- Bước 3: Tính tổng tiền bằng Function fn_TinhTongTienHoaDon
        SET @TongTien = dbo.fn_TinhTongTienHoaDon(@MaHoSo);

        -- Bước 4: Sinh MaHD tự động (HD001, HD002, ...)
        SELECT @SoThuTu = ISNULL(
            MAX(CAST(SUBSTRING(MaHD, 3, LEN(MaHD)) AS INT)), 0
        ) + 1
        FROM HoaDon
        WHERE MaHD LIKE 'HD%'
          AND ISNUMERIC(SUBSTRING(MaHD, 3, LEN(MaHD))) = 1;

        SET @MaHD = 'HD' + RIGHT('000' + CAST(@SoThuTu AS VARCHAR), 3);

        -- Bước 5: Tạo hóa đơn
        INSERT INTO HoaDon (MaHD, MaBN, MaHoSo, NgayLap, TongTien, TrangThaiTT)
        VALUES (@MaHD, @MaBN, @MaHoSo, GETDATE(), @TongTien, N'Chưa thanh toán');

        SET @MaHD_Out     = @MaHD;
        SET @TongTien_Out = @TongTien;

        PRINT N'Đã xuất hóa đơn: ' + @MaHD
            + N' | Tổng tiền: ' + FORMAT(@TongTien, 'N0') + N' VNĐ';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Err3 NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err3, 16, 1);
    END CATCH
END;
GO


-- ============================================================
-- PHẦN 2: FUNCTIONS
-- ============================================================


-- ============================================================
-- FUNCTION 1: fn_TinhTongTienHoaDon
-- Mục đích : Tính tổng tiền viện phí của một lần khám
--            = Tổng (SoLuong × GiaBan) của tất cả thuốc trong đơn
-- Input    : @MaHoSo — Mã hồ sơ bệnh án
-- Output   : DECIMAL(18,2) — Tổng tiền (trả 0 nếu chưa có đơn thuốc)
-- ============================================================
CREATE OR ALTER FUNCTION dbo.fn_TinhTongTienHoaDon(@MaHoSo VARCHAR(20))
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @TongTien DECIMAL(18, 2);

    SELECT @TongTien = ISNULL(SUM(ct.SoLuong * t.GiaBan), 0)
    FROM DonThuoc dt
    JOIN ChiTietDonThuoc ct ON dt.MaDon  = ct.MaDon
    JOIN Thuoc            t  ON ct.MaThuoc = t.MaThuoc
    WHERE dt.MaHoSo = @MaHoSo;

    RETURN @TongTien;
END;
GO  


-- ============================================================
-- FUNCTION 2: fn_KiemTraLichTrong
-- Mục đích : Kiểm tra bác sĩ có rảnh lịch tại thời điểm cho trước không
-- Input    :
--   @MaBS   — Mã bác sĩ cần kiểm tra
--   @NgayGio — Thời gian muốn đặt lịch
-- Output   : BIT
--   1 = Bác sĩ rảnh (có thể đặt lịch)
--   0 = Bác sĩ đã có lịch trong khoảng ±30 phút
-- ============================================================
CREATE OR ALTER FUNCTION dbo.fn_KiemTraLichTrong(
    @MaBS    VARCHAR(20),
    @NgayGio DATETIME
)
RETURNS BIT
AS
BEGIN
    DECLARE @KetQua BIT = 1; -- Mặc định: rảnh

    -- Kiểm tra có lịch hẹn nào trong khoảng 30 phút trước/sau không
    IF EXISTS (
        SELECT 1
        FROM LichHen
        WHERE MaBS = @MaBS
          AND TrangThai NOT IN (N'Đã hủy', N'Hoàn thành')
          AND ABS(DATEDIFF(MINUTE, NgayGio, @NgayGio)) < 30
    )
    BEGIN
        SET @KetQua = 0; -- Bận
    END

    RETURN @KetQua;
END;
GO


-- ============================================================
-- PHẦN 3: VÍ DỤ TEST — Copy từng block vào SSMS để chạy thử
-- ============================================================

-- ----------------------------------------------------------
-- Test fn_KiemTraLichTrong
-- Trả về 1 nếu bác sĩ rảnh, 0 nếu bận
-- ----------------------------------------------------------
-- SELECT dbo.fn_KiemTraLichTrong('BS001', '2026-05-27 09:00:00') AS LichTrong;

-- ----------------------------------------------------------
-- Test fn_TinhTongTienHoaDon
-- ----------------------------------------------------------
-- SELECT dbo.fn_TinhTongTienHoaDon('HS001') AS TongTien;

-- ----------------------------------------------------------
-- Test sp_TiepNhanBenhMoi — Bệnh nhân MỚI
-- ----------------------------------------------------------
-- DECLARE @OutBN VARCHAR(20), @OutLich VARCHAR(20);
-- EXEC sp_TiepNhanBenhMoi
--     @CCCD        = '012345678901',
--     @HoTen       = N'Nguyễn Văn A',
--     @NgaySinh    = '1990-01-15',
--     @GioiTinh    = N'Nam',
--     @DiaChi      = N'123 Đường ABC, TP.HCM',
--     @SDT         = '0901234567',
--     @NhomMau     = 'A+',
--     @TienSuBenh  = N'Không có',
--     @MaBS        = 'BS001',
--     @NgayGio     = '2026-05-27 09:00:00',
--     @LyDoKham    = N'Khám tổng quát',
--     @MaBN_Out    = @OutBN   OUTPUT,
--     @MaLich_Out  = @OutLich OUTPUT;
-- SELECT @OutBN AS MaBenhNhan, @OutLich AS MaLichHen;

-- ----------------------------------------------------------
-- Test sp_KeDonThuoc
-- ----------------------------------------------------------
-- DECLARE @OutDon VARCHAR(20);
-- DECLARE @Thuoc DanhSachThuocType;
-- INSERT INTO @Thuoc VALUES
--     ('TH001', 2, N'Uống sau ăn',  N'2 lần/ngày'),
--     ('TH002', 1, N'Uống trước ăn', N'1 lần/ngày');
-- EXEC sp_KeDonThuoc
--     @MaHoSo         = 'HS001',
--     @MaNV_KeDon     = 'NV001',
--     @HuongDanSuDung = N'Uống đúng giờ, không bỏ liều',
--     @DanhSachThuoc  = @Thuoc,
--     @MaDon_Out      = @OutDon OUTPUT;
-- SELECT @OutDon AS MaDonThuoc;

-- ----------------------------------------------------------
-- Test sp_XuatHoaDon
-- ----------------------------------------------------------
-- DECLARE @OutHD VARCHAR(20), @OutTien DECIMAL(18,2);
-- EXEC sp_XuatHoaDon
--     @MaHoSo       = 'HS001',
--     @MaHD_Out     = @OutHD   OUTPUT,
--     @TongTien_Out = @OutTien OUTPUT;
-- SELECT @OutHD AS MaHoaDon, FORMAT(@OutTien, 'N0') + N' VNĐ' AS TongTien;


-- ============================================================
-- PHẦN 4: PHÂN QUYỀN (LOGIN / USER / ROLE / GRANT / DENY)
-- Thực hiện: Tô Ngọc Huy
-- ============================================================

-- Tạo Login và User cho 4 vai trò
CREATE LOGIN Login_BacSi  WITH PASSWORD = 'BacSi@2026';
CREATE LOGIN Login_KeToan WITH PASSWORD = 'KeToan@2026';
CREATE LOGIN Login_Admin  WITH PASSWORD = 'Admin@2026';
CREATE LOGIN Login_YTa    WITH PASSWORD = 'YTa@2026';
CREATE USER  User_BacSi   FOR LOGIN Login_BacSi;
CREATE USER  User_KeToan  FOR LOGIN Login_KeToan;
GO

-- Tạo Role và gán User
CREATE ROLE Role_BacSi;  CREATE ROLE Role_KeToan;
ALTER ROLE Role_BacSi  ADD MEMBER User_BacSi;
ALTER ROLE Role_KeToan ADD MEMBER User_KeToan;
GO

-- Phân quyền cho Role_BacSi
GRANT SELECT, INSERT, UPDATE ON HoSoBenhAn  TO Role_BacSi;
GRANT SELECT, INSERT, UPDATE ON DonThuoc    TO Role_BacSi;
GRANT SELECT                 ON BenhNhan    TO Role_BacSi;
DENY  INSERT, UPDATE, DELETE ON HoaDon      TO Role_BacSi;
DENY  SELECT, INSERT, UPDATE ON NhanVien    TO Role_BacSi;
GO

-- Phân quyền cho Role_KeToan
GRANT SELECT, INSERT, UPDATE ON HoaDon      TO Role_KeToan;
GRANT SELECT                 ON HoSoBenhAn  TO Role_KeToan;
DENY  INSERT, UPDATE, DELETE ON HoSoBenhAn  TO Role_KeToan;
DENY  SELECT, INSERT, UPDATE ON NhanVien    TO Role_KeToan;
GO
