

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ApproveCourse
    @review_id   INT,
    @reviewer_id INT,
    @comments    VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 FROM academic_reviews
        WHERE id = @review_id AND reviewer_id = @reviewer_id AND status = 'in_progress'
    )
        THROW 52001, 'La revision no existe, no esta en progreso, o no pertenece a este revisor.', 1;

    DECLARE @course_id INT, @category_id INT, @title VARCHAR(200);
    SELECT @course_id = course_id FROM academic_reviews WHERE id = @review_id;

    -- nuevo check, validar estado del curso:
    IF NOT EXISTS (SELECT 1 FROM courses WHERE id = @course_id AND status = 'under_review')
        THROW 52003, 'El curso asociado no esta en estado under_review.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE academic_reviews
            SET result = 'approved', comments = @comments, finished_at = GETDATE(), status = 'finished'
        WHERE id = @review_id AND status = 'in_progress';

        IF @@ROWCOUNT = 0
            THROW 52002, 'La revision ya no esta en progreso (fue resuelta por otra sesion).', 1;

        UPDATE courses
            SET status = 'available', published_at = GETDATE()
        WHERE id = @course_id;

        SELECT @category_id = category_id, @title = title FROM courses WHERE id = @course_id;

        INSERT INTO notifications (user_id, type, subject, body)
        SELECT ci.instructor_id, 'approved', CONCAT('Tu curso "', @title, '" fue aprobado'),
               CONCAT('Felicidades, tu curso "', @title, '" ya esta disponible en EduGT.')
        FROM course_instructors ci
        WHERE ci.course_id = @course_id AND ci.is_main = 1;

        INSERT INTO notifications (user_id, type, subject, body)
        SELECT cs.user_id, 'new_course', CONCAT('Nuevo curso en tu categoria: ', @title),
               CONCAT('Se publico un nuevo curso "', @title, '" en una categoria a la que estas suscrito.')
        FROM category_subscriptions cs
        WHERE cs.category_id = @category_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
