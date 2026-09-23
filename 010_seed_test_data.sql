
DELETE FROM notifications WHERE user_id IN (
    SELECT id FROM users WHERE email IN (
        'admin.test@edugt.com', 'instructor.test@edugt.com',
        'coinstructor.test@edugt.com', 'academic.test@edugt.com', 'academic2.test@edugt.com'
    )
);
DELETE FROM academic_reviews WHERE reviewer_id IN (
    SELECT id FROM users WHERE email IN (
        'admin.test@edugt.com', 'instructor.test@edugt.com',
        'coinstructor.test@edugt.com', 'academic.test@edugt.com', 'academic2.test@edugt.com'
    )
);
DELETE FROM academic_reviews WHERE course_id IN (SELECT id FROM courses WHERE code = 'EDU-TEST-EXISTING');
DELETE FROM course_instructors WHERE instructor_id IN (
    SELECT id FROM users WHERE email IN (
        'admin.test@edugt.com', 'instructor.test@edugt.com',
        'coinstructor.test@edugt.com', 'academic.test@edugt.com', 'academic2.test@edugt.com'
    )
);
DELETE FROM course_prerequisites WHERE prerequisite_id IN (SELECT id FROM courses WHERE code = 'EDU-TEST-EXISTING');
DELETE FROM lessons WHERE module_id IN (
    SELECT m.id FROM modules m JOIN courses c ON c.id = m.course_id WHERE c.code = 'EDU-TEST-EXISTING'
);
DELETE FROM modules WHERE course_id IN (SELECT id FROM courses WHERE code = 'EDU-TEST-EXISTING');
DELETE FROM course_prerequisites WHERE course_id IN (SELECT id FROM courses WHERE code = 'EDU-TEST-EXISTING');
DELETE FROM course_instructors WHERE course_id IN (SELECT id FROM courses WHERE code = 'EDU-TEST-EXISTING');
DELETE FROM courses WHERE code = 'EDU-TEST-EXISTING';

DELETE FROM platform_config WHERE id = 1;
DELETE FROM users WHERE email IN (
    'admin.test@edugt.com', 'instructor.test@edugt.com',
    'coinstructor.test@edugt.com', 'academic.test@edugt.com', 'academic2.test@edugt.com'
);

INSERT INTO users (first_name, last_name, email, password_hash, role) VALUES
    ('Admin', 'Test', 'admin.test@edugt.com', 'hash', 'admin'),
    ('Instructor', 'Test', 'instructor.test@edugt.com', 'hash', 'instructor'),
    ('CoInstructor', 'Test', 'coinstructor.test@edugt.com', 'hash', 'instructor'),
    ('Academic', 'One', 'academic.test@edugt.com', 'hash', 'academic'),
    ('Academic', 'Two', 'academic2.test@edugt.com', 'hash', 'academic');

INSERT INTO platform_config (id, course_price_min, course_price_max, updated_by)
SELECT 1, 1.00, 5000.00, id FROM users WHERE email = 'admin.test@edugt.com';

IF NOT EXISTS (SELECT 1 FROM categories WHERE name = 'Categoria Test')
    INSERT INTO categories (name, description, platform_commission)
    VALUES ('Categoria Test', 'Categoria para pruebas', 25.00);


INSERT INTO courses (code, title, description, category_id, price, status, published_at)
SELECT 'EDU-TEST-EXISTING', 'Curso Prerequisito de Prueba', 'Curso ya publicado para pruebas de prerequisitos',
       (SELECT id FROM categories WHERE name = 'Categoria Test'), 100.00, 'available', GETDATE();