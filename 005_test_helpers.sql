
CREATE OR ALTER PROCEDURE dbo.test_pass
    @test_name VARCHAR(200)
AS
BEGIN
    PRINT CONCAT('PASS: ', @test_name);
END

CREATE OR ALTER PROCEDURE dbo.test_fail
    @test_name VARCHAR(200),
    @detail    VARCHAR(400) = NULL
AS
BEGIN
    DECLARE @msg VARCHAR(620) =
        CONCAT('FAIL: ', @test_name, CASE WHEN @detail IS NOT NULL THEN CONCAT(' -- ', @detail) ELSE '' END);
    RAISERROR('%s', 16, 1, @msg);
END

CREATE OR ALTER PROCEDURE dbo.test_expect_error
    @test_name      VARCHAR(200),
    @error_fragment VARCHAR(200),
    @actual_error   VARCHAR(2048)
AS
BEGIN
    IF @actual_error LIKE '%' + @error_fragment + '%'
        EXEC dbo.test_pass @test_name;
    ELSE
    BEGIN
        DECLARE @mismatch_detail VARCHAR(2400) =
            CONCAT('se esperaba error con "', @error_fragment, '" pero fue: ', @actual_error);
        EXEC dbo.test_fail @test_name, @detail = @mismatch_detail;
    END
END
