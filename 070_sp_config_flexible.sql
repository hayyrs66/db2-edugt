

CREATE OR ALTER PROCEDURE dbo.sp_ResubmitCourseForReview
    @course_id     INT,
    @instructor_id INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM courses WHERE id = @course_id AND status = 'rejected')
        THROW 54001, 'El curso no existe o no esta en estado rejected.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM course_instructors
        WHERE course_id = @course_id AND instructor_id = @instructor_id AND is_main = 1
    )
        THROW 54002, 'Solo el instructor principal puede reenviar el curso a revision.', 1;

    UPDATE courses SET status = 'pending' WHERE id = @course_id AND status = 'rejected';

    IF @@ROWCOUNT = 0
        THROW 54003, 'El curso ya no esta en estado rejected (fue modificado por otra sesion).', 1;
END
GO
