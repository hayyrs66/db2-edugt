
CREATE TYPE dbo.ModuleTableType AS TABLE (
    order_index INT NOT NULL,
    title       VARCHAR(200) NOT NULL,
    description VARCHAR(500) NULL
);
GO

CREATE TYPE dbo.LessonTableType AS TABLE (
    module_order_index INT NOT NULL,
    order_index         INT NOT NULL,
    title               VARCHAR(200) NOT NULL,
    type                VARCHAR(20) NOT NULL,
    content_url         VARCHAR(500) NULL,
    duration_min        INT NULL
);
GO

CREATE TYPE dbo.CoInstructorTableType AS TABLE (
    instructor_id INT NOT NULL,
    share_percent DECIMAL(5,2) NOT NULL,
    is_main       BIT NOT NULL
);
GO

CREATE TYPE dbo.PrerequisiteTableType AS TABLE (
    prerequisite_course_id INT NOT NULL
);
GO
