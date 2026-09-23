DECLARE @academic1    INT = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
DECLARE @academic2    INT = (SELECT id FROM users WHERE email = 'academic2.test@edugt.com');
DECLARE @category     INT = (SELECT id FROM categories WHERE name = 'Categoria Test');
DECLARE @course_id    INT;
DECLARE @error1       VARCHAR(2048) = NULL;
DECLARE @error2       VARCHAR(2048) = NULL;
DECLARE @active_count INT;
DECLARE @msg_concur   VARCHAR(200);

PRINT 'PRUEBA DE CONCURRENCIA: REVISION ACADEMICA';

-- Limpiar residuos de corridas anteriores.
DELETE FROM academic_reviews WHERE course_id IN (SELECT id FROM courses WHERE code = 'EDU-TEST-CONCUR');
DELETE FROM courses WHERE code = 'EDU-TEST-CONCUR';

-- Crear el curso de prueba.
INSERT INTO courses (code, title, description, category_id, price, status)
VALUES ('EDU-TEST-CONCUR', 'Curso Prueba Concurrencia', 'Curso para probar la contencion de revision',
        @category, 100.00, 'pending');

SET @course_id = SCOPE_IDENTITY();

-- Sesion 1: academico 1 reclama el curso (debe pasar).
BEGIN TRY
    EXEC dbo.sp_ClaimCourseForReview @course_id = @course_id, @reviewer_id = @academic1;
END TRY
BEGIN CATCH
    SET @error1 = ERROR_MESSAGE();
END CATCH

IF @error1 IS NULL
    EXEC dbo.test_pass 'Primer academico reclama el curso correctamente';
ELSE
    EXEC dbo.test_fail 'Primer academico reclama el curso correctamente', @detail = @error1;

-- Sesion 2: academico 2 intenta reclamar el MISMO curso (debe fallar).
-- Ya existe una revision in_progress: el indice unico filtrado la rechaza.
BEGIN TRY
    EXEC dbo.sp_ClaimCourseForReview @course_id = @course_id, @reviewer_id = @academic2;
END TRY
BEGIN CATCH
    SET @error2 = ERROR_MESSAGE();
END CATCH

EXEC dbo.test_expect_error
    @test_name      = 'Segundo academico es rechazado (no hay doble revision)',
    @error_fragment = 'ya esta siendo revisado',
    @actual_error   = @error2;

-- Verificar que solo existe UNA revision activa.
SET @active_count = (
    SELECT COUNT(*) FROM academic_reviews
    WHERE course_id = @course_id AND status = 'in_progress'
);

SET @msg_concur = CONCAT('Se encontraron ', CAST(@active_count AS VARCHAR(5)), ' revisiones activas (se esperaba 1).');

IF @active_count = 1
    EXEC dbo.test_pass 'Existe exactamente una revision activa para el curso';
ELSE
    EXEC dbo.test_fail 'Existe exactamente una revision activa para el curso', @detail = @msg_concur;

-- Limpieza.
DELETE FROM academic_reviews WHERE course_id = @course_id;
DELETE FROM courses WHERE id = @course_id;

PRINT '';
PRINT 'Fin de la prueba automatica de concurrencia.';

-- PARTE B: GUION PARA DEMO MANUAL DE DOS SESIONES SIMULTANEAS
-- Abrir DOS ventanas de consulta separadas conectadas a la misma base
-- y ejecutar los bloques casi al mismo tiempo con WAITFOR TIME.
--
-- PASO 0 (ejecutar UNA sola vez para preparar el curso):
--
--     INSERT INTO courses (code, title, description, category_id, price, status)
--     VALUES ('EDU-DEMO-CONCUR', 'Demo Concurrencia', 'Demo en vivo',
--             (SELECT id FROM categories WHERE name = 'Categoria Test'), 100.00, 'pending');
--
-- PASO 1 - Ventana 1 (academico 1). Ajustar hora a ~1 min en el futuro:
--
--     WAITFOR TIME '14:30:00';
--     EXEC dbo.sp_ClaimCourseForReview
--         @course_id   = (SELECT id FROM courses WHERE code = 'EDU-DEMO-CONCUR'),
--         @reviewer_id = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
--
-- PASO 2 - Ventana 2 (academico 2). MISMA hora exacta que la ventana 1:
--
--     WAITFOR TIME '14:30:00';
--     EXEC dbo.sp_ClaimCourseForReview
--         @course_id   = (SELECT id FROM courses WHERE code = 'EDU-DEMO-CONCUR'),
--         @reviewer_id = (SELECT id FROM users WHERE email = 'academic2.test@edugt.com');
--
-- RESULTADO ESPERADO:
--   - Una ventana termina sin error (gano la carrera).
--   - La otra recibe: "Este curso ya esta siendo revisado por otro academico."
--   - Nunca quedan dos revisiones in_progress para el mismo curso.
--
-- LIMPIEZA despues de la demo:
--     DELETE FROM academic_reviews WHERE course_id IN (SELECT id FROM courses WHERE code = 'EDU-DEMO-CONCUR');
--     DELETE FROM courses WHERE code = 'EDU-DEMO-CONCUR';