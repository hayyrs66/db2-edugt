CREATE OR ALTER PROCEDURE dbo.sp_ClaimCourseForReview
    @course_id   INT,
    @reviewer_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = @reviewer_id AND role = 'academic')
        THROW 51001, 'El revisor especificado no existe o no tiene rol academic.', 1;

    IF NOT EXISTS (SELECT 1 FROM courses WHERE id = @course_id AND status IN ('pending', 'under_review'))
        THROW 51002, 'El curso no existe o no esta en estado pending ni under_review.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO academic_reviews (course_id, reviewer_id, started_at, status)
        VALUES (@course_id, @reviewer_id, GETDATE(), 'in_progress');

        UPDATE courses SET status = 'under_review' WHERE id = @course_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51003, 'Este curso ya esta siendo revisado por otro academico.', 1;

        THROW;
    END CATCH
END
