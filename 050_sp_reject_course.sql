
CREATE OR ALTER PROCEDURE dbo.sp_RejectCourse
    @review_id   INT,
    @reviewer_id INT,
    @comments    VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @comments IS NULL OR PATINDEX('%[^ ' + CHAR(9) + CHAR(10) + CHAR(13) + ']%', @comments) = 0
        THROW 53001, 'Debe indicar un comentario explicando el motivo del rechazo.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM academic_reviews
        WHERE id = @review_id AND reviewer_id = @reviewer_id AND status = 'in_progress'
    )
        THROW 53002, 'La revision no existe, no esta en progreso, o no pertenece a este revisor.', 1;

    DECLARE @course_id INT, @title VARCHAR(200);
    SELECT @course_id = course_id FROM academic_reviews WHERE id = @review_id;
    SELECT @title = title FROM courses WHERE id = @course_id;
    
    IF NOT EXISTS (SELECT 1 FROM courses WHERE id = @course_id AND status = 'under_review')
        THROW 53004, 'El curso asociado no esta en estado under_review.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE academic_reviews
            SET result = 'rejected', comments = @comments, finished_at = GETDATE(), status = 'finished'
        WHERE id = @review_id AND status = 'in_progress';

        IF @@ROWCOUNT = 0
            THROW 53003, 'La revision ya no esta en progreso (fue resuelta por otra sesion).', 1;

        UPDATE courses SET status = 'rejected' WHERE id = @course_id;

        INSERT INTO notifications (user_id, type, subject, body)
        SELECT ci.instructor_id, 'rejected', CONCAT('Tu curso "', @title, '" fue rechazado'), @comments
        FROM course_instructors ci
        WHERE ci.course_id = @course_id AND ci.is_main = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
