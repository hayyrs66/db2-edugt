SET QUOTED_IDENTIFIER ON;
GO

PRINT 'PRUEBAS FUNCIONALES: FLUJO DE REVISION';
GO

-- Helper local: crea un curso de prueba directo en un estado dado y
-- devuelve su id. Evita repetir toda la construccion de TVPs en cada test.
CREATE OR ALTER PROCEDURE dbo.test_make_course
    @title     VARCHAR(200),
    @status    VARCHAR(20),
    @course_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @category INT = (SELECT id FROM categories WHERE name = 'Categoria Test');
    DECLARE @instr    INT = (SELECT id FROM users WHERE email = 'instructor.test@edugt.com');

    INSERT INTO courses (code, title, description, category_id, price, status)
    VALUES (CONCAT('EDU-TR-', RIGHT(CONVERT(VARCHAR(36), NEWID()), 8)), @title, 'Curso de prueba de flujo',
            @category, 100.00, @status);
    SET @course_id = SCOPE_IDENTITY();

    -- El curso necesita un instructor principal para las notificaciones.
    INSERT INTO course_instructors (course_id, instructor_id, is_main, share_percent)
    VALUES (@course_id, @instr, 1, 100.00);
END
GO

-- Helper local: limpia todo lo creado por estas pruebas.

CREATE OR ALTER PROCEDURE dbo.test_cleanup_review_courses
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ids TABLE (id INT);
    INSERT INTO @ids SELECT id FROM courses WHERE title LIKE 'TEST Review%';

    DELETE FROM notifications WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%.test@edugt.com')
        AND type IN ('approved', 'rejected', 'new_course');
    DELETE FROM academic_reviews WHERE course_id IN (SELECT id FROM @ids);
    DELETE FROM course_instructors WHERE course_id IN (SELECT id FROM @ids);
    DELETE FROM courses WHERE id IN (SELECT id FROM @ids);
END
GO

EXEC dbo.test_cleanup_review_courses;
GO
-- FLUJO 1: pending -> claim -> approve -> available
DECLARE @academic INT = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
DECLARE @course INT;
EXEC dbo.test_make_course 'TEST Review Aprobacion', 'pending', @course OUTPUT;

DECLARE @err VARCHAR(2048) = NULL;

-- Claim
BEGIN TRY
    EXEC dbo.sp_ClaimCourseForReview @course_id = @course, @reviewer_id = @academic;
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH

IF @err IS NULL AND EXISTS (SELECT 1 FROM courses WHERE id = @course AND status = 'under_review')
    EXEC dbo.test_pass 'Claim: curso pasa a under_review';
ELSE
    EXEC dbo.test_fail 'Claim: curso pasa a under_review', @detail = @err;

-- Approve
DECLARE @review INT = (SELECT id FROM academic_reviews WHERE course_id = @course AND status = 'in_progress');
SET @err = NULL;
BEGIN TRY
    EXEC dbo.sp_ApproveCourse @review_id = @review, @reviewer_id = @academic, @comments = 'Buen contenido';
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH

IF @err IS NULL AND EXISTS (SELECT 1 FROM courses WHERE id = @course AND status = 'available' AND published_at IS NOT NULL)
    EXEC dbo.test_pass 'Approve: curso pasa a available con published_at';
ELSE
    EXEC dbo.test_fail 'Approve: curso pasa a available con published_at', @detail = @err;

-- La review debe quedar finished/approved
IF EXISTS (SELECT 1 FROM academic_reviews WHERE id = @review AND status = 'finished' AND result = 'approved')
    EXEC dbo.test_pass 'Approve: la revision queda finished/approved';
ELSE
    EXEC dbo.test_fail 'Approve: la revision queda finished/approved';

-- Debe existir notificacion 'approved' al instructor
IF EXISTS (SELECT 1 FROM notifications n JOIN course_instructors ci ON ci.instructor_id = n.user_id
           WHERE ci.course_id = @course AND ci.is_main = 1 AND n.type = 'approved')
    EXEC dbo.test_pass 'Approve: se notifica al instructor principal';
ELSE
    EXEC dbo.test_fail 'Approve: se notifica al instructor principal';
GO

-- FLUJO 2: pending -> claim -> reject -> rejected -> resubmit -> pending
DECLARE @academic INT = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
DECLARE @instr    INT = (SELECT id FROM users WHERE email = 'instructor.test@edugt.com');
DECLARE @course INT;
EXEC dbo.test_make_course 'TEST Review Rechazo', 'pending', @course OUTPUT;

DECLARE @err VARCHAR(2048) = NULL;

-- Claim
EXEC dbo.sp_ClaimCourseForReview @course_id = @course, @reviewer_id = @academic;
DECLARE @review INT = (SELECT id FROM academic_reviews WHERE course_id = @course AND status = 'in_progress');

-- Reject
BEGIN TRY
    EXEC dbo.sp_RejectCourse @review_id = @review, @reviewer_id = @academic,
        @comments = 'Falta profundidad en el modulo 2';
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH

IF @err IS NULL AND EXISTS (SELECT 1 FROM courses WHERE id = @course AND status = 'rejected')
    EXEC dbo.test_pass 'Reject: curso pasa a rejected';
ELSE
    EXEC dbo.test_fail 'Reject: curso pasa a rejected', @detail = @err;

-- Resubmit por el instructor principal
SET @err = NULL;
BEGIN TRY
    EXEC dbo.sp_ResubmitCourseForReview @course_id = @course, @instructor_id = @instr;
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH

IF @err IS NULL AND EXISTS (SELECT 1 FROM courses WHERE id = @course AND status = 'pending')
    EXEC dbo.test_pass 'Resubmit: curso vuelve a pending';
ELSE
    EXEC dbo.test_fail 'Resubmit: curso vuelve a pending', @detail = @err;
GO

-- CASOS DE ERROR

-- ERROR 51001: reviewer sin rol academic (usar un instructor como revisor)
DECLARE @course INT, @err VARCHAR(2048) = NULL;
DECLARE @instr INT = (SELECT id FROM users WHERE email = 'instructor.test@edugt.com');
EXEC dbo.test_make_course 'TEST Review NoAcademic', 'pending', @course OUTPUT;
BEGIN TRY
    EXEC dbo.sp_ClaimCourseForReview @course_id = @course, @reviewer_id = @instr;
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH
EXEC dbo.test_expect_error 'Claim rechaza revisor sin rol academic', 'rol academic', @err;
GO

-- ERROR 53001: rechazo sin comentario
DECLARE @course INT, @err VARCHAR(2048) = NULL;
DECLARE @academic INT = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
EXEC dbo.test_make_course 'TEST Review SinComentario', 'pending', @course OUTPUT;
EXEC dbo.sp_ClaimCourseForReview @course_id = @course, @reviewer_id = @academic;
DECLARE @review INT = (SELECT id FROM academic_reviews WHERE course_id = @course AND status = 'in_progress');
BEGIN TRY
    EXEC dbo.sp_RejectCourse @review_id = @review, @reviewer_id = @academic, @comments = '   ';
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH
EXEC dbo.test_expect_error 'Reject rechaza comentario vacio', 'comentario', @err;
GO

-- ERROR 52001: aprobar una review que no pertenece al reviewer
DECLARE @course INT, @err VARCHAR(2048) = NULL;
DECLARE @academic  INT = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
DECLARE @academic2 INT = (SELECT id FROM users WHERE email = 'academic2.test@edugt.com');
EXEC dbo.test_make_course 'TEST Review OtroRevisor', 'pending', @course OUTPUT;
EXEC dbo.sp_ClaimCourseForReview @course_id = @course, @reviewer_id = @academic;
DECLARE @review INT = (SELECT id FROM academic_reviews WHERE course_id = @course AND status = 'in_progress');
BEGIN TRY
    -- academic2 intenta aprobar una review que reclamo academic1
    EXEC dbo.sp_ApproveCourse @review_id = @review, @reviewer_id = @academic2, @comments = 'ok';
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH
EXEC dbo.test_expect_error 'Approve rechaza revisor que no es dueno de la revision', 'no pertenece a este revisor', @err;
GO

-- ERROR 54002: resubmit por alguien que no es el instructor principal
DECLARE @course INT, @err VARCHAR(2048) = NULL;
DECLARE @academic INT = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
DECLARE @coinstr  INT = (SELECT id FROM users WHERE email = 'coinstructor.test@edugt.com');
EXEC dbo.test_make_course 'TEST Review ResubmitAjeno', 'pending', @course OUTPUT;
EXEC dbo.sp_ClaimCourseForReview @course_id = @course, @reviewer_id = @academic;
DECLARE @review INT = (SELECT id FROM academic_reviews WHERE course_id = @course AND status = 'in_progress');
EXEC dbo.sp_RejectCourse @review_id = @review, @reviewer_id = @academic, @comments = 'motivo';
BEGIN TRY
    EXEC dbo.sp_ResubmitCourseForReview @course_id = @course, @instructor_id = @coinstr;
END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH
EXEC dbo.test_expect_error 'Resubmit rechaza a quien no es instructor principal', 'instructor principal', @err;
GO

-- Limpieza final.
EXEC dbo.test_cleanup_review_courses;
GO

PRINT '';
PRINT 'Fin de pruebas del flujo de revision.';
GO