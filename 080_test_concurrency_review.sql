
SET QUOTED_IDENTIFIER ON;
GO

-- PARTE A: PRUEBA AUTOMATICA DETERMINISTA

-- No se pueden abrir dos hilos reales dentro de un mismo script de T-SQL,
-- pero si se puede reproducir de forma DETERMINISTA la condicion exacta que
-- ocurre: dejar una revision activa y comprobar que un segundo
-- intento sobre el mismo curso es rechazado por el indice. Esto prueba que la
-- salvaguarda funciona sin depender del azar del scheduler.

PRINT 'PRUEBA DE CONCURRENCIA: REVISION ACADEMICA';
GO

-- curso limpio en estado 'pending' para la prueba.
DECLARE @academic1 INT = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
DECLARE @academic2 INT = (SELECT id FROM users WHERE email = 'academic2.test@edugt.com');
DECLARE @category  INT = (SELECT id FROM categories WHERE name = 'Categoria Test');

-- Limpiar residuos de corridas anteriores.
DELETE FROM academic_reviews WHERE course_id IN (SELECT id FROM courses WHERE code = 'EDU-TEST-CONCUR');
DELETE FROM courses WHERE code = 'EDU-TEST-CONCUR';

INSERT INTO courses (code, title, description, category_id, price, status)
VALUES ('EDU-TEST-CONCUR', 'Curso Prueba Concurrencia', 'Curso para probar la contencion de revision',
        @category, 100.00, 'pending');

DECLARE @course_id INT = SCOPE_IDENTITY();

-- --- Sesion 1 (academico 1): reclama el curso. Debe tener exito.
DECLARE @error1 VARCHAR(2048) = NULL;
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

-- --- Sesion 2 (academico 2): intenta reclamar el MISMO curso. Debe fallar. ---
-- En este punto ya existe una revision in_progress para el curso, exactamente
-- el estado en el que quedaria si la sesion 1 hubiera ganado la carrera por
-- microsegundos. El indice unico filtrado debe rechazar este segundo intento.
DECLARE @error2 VARCHAR(2048) = NULL;
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

-- --- Comprobacion final: solo debe existir UNA revision activa del curso. ---
DECLARE @active_reviews INT =
    (SELECT COUNT(*) FROM academic_reviews WHERE course_id = @course_id AND status = 'in_progress');

IF @active_reviews = 1
    EXEC dbo.test_pass 'Existe exactamente una revision activa para el curso';
ELSE
    EXEC dbo.test_fail 'Existe exactamente una revision activa para el curso',
         @detail = CONCAT('Se encontraron ', @active_reviews, ' revisiones activas (se esperaba 1).');

-- Limpieza.
DELETE FROM academic_reviews WHERE course_id = @course_id;
DELETE FROM courses WHERE id = @course_id;
GO

PRINT '';
PRINT 'Fin de la prueba automatica de concurrencia.';
GO


-- Para demostrar la concurrencia REAL (dos hilos golpeando a la vez) ante el
-- docente, abrir DOS ventanas de consulta separadas en SSMS conectadas a la
-- misma base, y ejecutar los bloques casi al mismo tiempo. El WAITFOR TIME
-- sincroniza ambas sesiones para que intenten insertar en el mismo instante.
--
-- PASO 0 (ejecutar UNA sola vez, en cualquier ventana, para preparar el curso):
--
--     INSERT INTO courses (code, title, description, category_id, price, status)
--     VALUES ('EDU-DEMO-CONCUR', 'Demo Concurrencia', 'Demo en vivo',
--             (SELECT id FROM categories WHERE name = 'Categoria Test'), 100.00, 'pending');
--
-- PASO 1 — Ventana 1 (academico 1). Ajustar la hora a ~1 min en el futuro:
--
--     WAITFOR TIME '14:30:00';
--     EXEC dbo.sp_ClaimCourseForReview
--         @course_id   = (SELECT id FROM courses WHERE code = 'EDU-DEMO-CONCUR'),
--         @reviewer_id = (SELECT id FROM users WHERE email = 'academic.test@edugt.com');
--
-- PASO 2 — Ventana 2 (academico 2). MISMA hora exacta que la ventana 1:
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
