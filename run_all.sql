

-- 1. TIPOS DE TABLA (TVP)

:r "/workspace/fase 2/phase2/000_types.sql"


-- 2. HELPERS DE PRUEBA

:r "/workspace/fase 2/phase2/005_test_helpers.sql"


-- 3. DATOS SEMILLA PARA PRUEBAS

:r "/workspace/fase 2/phase2/010_seed_test_data.sql"


-- 4. PROCEDIMIENTOS ALMACENADOS — FLUJO PRINCIPAL

:r "/workspace/fase 2/phase2/020_sp_create_course.sql"
:r "/workspace/fase 2/phase2/030_sp_claim_course_for_review.sql"
:r "/workspace/fase 2/phase2/040_sp_approve_course.sql"
:r "/workspace/fase 2/phase2/050_sp_reject_course.sql"
:r "/workspace/fase 2/phase2/060_sp_resubmit_course_for_review.sql"


-- 5. PROCEDIMIENTOS ALMACENADOS — CONFIGURACIÓN FLEXIBLE

:r "/workspace/fase 2/phase2/070_sp_config_flexible.sql"


-- 6. PRUEBAS FUNCIONALES

:r "/workspace/fase 2/phase2/080_test_concurrency_review.sql"
:r "/workspace/fase 2/phase2/090_test_create_course.sql"
:r "/workspace/fase 2/phase2/100_test_review_flow.sql"



PRINT 'Fase 2 desplegada y probada correctamente.';

GO