DROP TABLE IF EXISTS #temp

-- Create a temporary table to hold the data from the CSV file
CREATE TABLE #temp (
    id NVARCHAR(50),
    parent_id NVARCHAR(50),
    brand NVARCHAR(50),
    brand_id NVARCHAR(255),
    top_category NVARCHAR(100),
	sub_category NVARCHAR(100),
	category_tags NVARCHAR(max),
	postal_code NVARCHAR(6),
	location_name NVARCHAR(150),
	latitude DECIMAL(18,6) NOT NULL,
    longitude DECIMAL(18,6) NOT NULL,
	country_code NVARCHAR(2) NOT NULL, 
	city NVARCHAR(1000) NOT NULL,
	region NVARCHAR(2) NOT NULL,
	operation_hours NVARCHAR(1000) NULL,
	geometry_type NVARCHAR(20) NULL,
	polygon_wkt NVARCHAR(MAX) NULL
);

-- Index for #temp.location_name
CREATE INDEX idx_temp_location_name ON #temp (location_name);

-- Index for #temp.brand
CREATE INDEX idx_temp_brand ON #temp (brand);


-- Bulk insert data from the CSV file into the temporary table
BULK INSERT #temp
FROM 'C:\Users\marprojo\Downloads\phoenix.csv'
WITH (
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
	CODEPAGE = '65001' --specifies the UTF-8 encoding for the file
);

BEGIN TRANSACTION

-- Delete invalid POLYGONS
DELETE FROM #temp 
WHERE geometry::STGeomFromText(polygon_wkt, 4326).STIsValid() <> 1;

INSERT INTO Category(name)
SELECT DISTINCT top_category  
FROM #temp
WHERE top_category IS NOT NULL;

-- Insert distinct brands into the Brands table
WITH CTE_brand AS (
    SELECT s.Value AS name,
           CONCAT(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), '_', i.[Index]) AS row_num,
           t.top_category AS [category]
    FROM #temp t
    CROSS APPLY (
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [Index], Value
        FROM STRING_SPLIT(t.brand,
            CASE 
                WHEN (LEN(t.brand_id) - LEN(REPLACE(t.brand_id, ',', ''))) = (LEN(t.brand) - LEN(REPLACE(t.brand, ',', '')))
                THEN ','
                ELSE '@'  -- any other not used character
            END
        )
    ) i
    CROSS APPLY (
        SELECT Value
        FROM STRING_SPLIT(i.value,
            CASE 
                WHEN (LEN(t.brand_id) - LEN(REPLACE(t.brand_id, ',', ''))) = (LEN(t.brand) - LEN(REPLACE(t.brand, ',', '')))
                THEN ','
                ELSE '@'  -- any other not used character
            END
        )
    ) s
),
CTE_brand_id AS (
    SELECT s.Value AS id,
           CONCAT(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), '_', i.[Index]) AS row_num,
           t.top_category AS [category]
    FROM #temp t
    CROSS APPLY (
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [Index], Value
        FROM STRING_SPLIT(t.brand_id, ',')
    ) i
    CROSS APPLY (
        SELECT Value
        FROM STRING_SPLIT(i.Value, ',')
    ) s
)
INSERT INTO Brand(id, name)
SELECT DISTINCT brid.id, br.name
FROM CTE_brand br 
JOIN CTE_brand_id brid ON br.row_num = brid.row_num
ORDER BY brid.id;

INSERT INTO SubCategory(name, [category_id])
SELECT DISTINCT sub_category, 
(select id from Category where name = #temp.top_category) 
FROM #temp
WHERE top_category IS NOT NULL;

-- Insert Tags
INSERT INTO tag (name)
SELECT DISTINCT value
FROM #temp
CROSS APPLY STRING_SPLIT(category_tags, ',') AS tags
WHERE LEN(tags.value) > 0 -- Exclude empty tags
AND NOT EXISTS (
  SELECT 1 FROM tag WHERE name = tags.value
);

INSERT INTO Category_Tag(category_id, tag_id)
SELECT DISTINCT tc.id, t.id
FROM #temp c
CROSS APPLY STRING_SPLIT(category_tags, ',') AS tags
INNER JOIN tag t ON t.name = tags.value
INNER JOIN Category tc on c.top_category = tc.name
WHERE NOT EXISTS (
    SELECT 1
    FROM Category_Tag tct
    WHERE tct.category_id = tc.id
    AND tct.tag_id = t.id
);

INSERT INTO Country
VALUES('United States', 'US', 'eng');

INSERT INTO Region
SELECT DISTINCT region, c.id
FROM #temp t
INNER JOIN Country c ON t.country_code = c.code;

INSERT INTO City
SELECT DISTINCT t.city, r.id
FROM #temp t
INNER JOIN Region r ON t.region = r.name AND r.country_id = (SELECT id FROM Country cou WHERE cou.code = t.country_code);

INSERT INTO PostalCode
SELECT DISTINCT t.postal_code, c.id 
FROM #temp t
INNER JOIN city c ON t.city = c.name 
AND c.region_id = (SELECT r.id FROM Region r WHERE r.name = t.region AND r.country_id = (SELECT c.id FROM Country c WHERE c.code = t.country_code));

INSERT INTO LocationName
SELECT DISTINCT location_name FROM #temp;

INSERT INTO OperationsHours
SELECT DISTINCT operation_hours 
FROM #temp t 
WHERE operation_hours IS NOT NULL;

-- Delete the records that don't have valid parents and its children rows: 
WITH RowsToDelete AS (
    SELECT id, parent_id
    FROM #temp
    WHERE parent_id IS NOT NULL
    AND parent_id NOT IN (SELECT id FROM #temp)
)
DELETE FROM #temp
WHERE id IN (SELECT id FROM RowsToDelete)
    OR parent_id IN (SELECT id FROM RowsToDelete);

INSERT INTO Location(id, parent_id, location_name_id, category_id, sub_category_id, city_id, operation_hours_id, postal_code_id)
SELECT DISTINCT  
    t.id,
    t.parent_id,
    ln.id AS location_name_id,
    cat.id AS category_id,
    scat.id AS sub_category_id,
    c.id  AS city_id,
    oh.id AS operation_hours_id,
    pc.id AS postal_code_id
FROM #temp t 
INNER JOIN LocationName ln ON t.location_name = ln.name
INNER JOIN City c ON c.name = t.city  
    AND c.region_id = (SELECT r.id FROM Region r WHERE r.name = t.region AND r.country_id = (SELECT cou.id FROM Country cou WHERE cou.code = t.country_code))
INNER JOIN PostalCode pc ON t.postal_code = pc.code
LEFT JOIN OperationsHours oh ON oh.value = t.operation_hours
LEFT JOIN SubCategory scat ON t.sub_category = scat.name AND scat.category_id = (SELECT id FROM Category cat WHERE cat.name = t.top_category)
LEFT JOIN Category cat ON cat.name = t.top_category;

INSERT INTO GeometryType
SELECT DISTINCT geometry_type FROM #temp;

INSERT INTO WKT
SELECT DISTINCT  t.polygon_wkt, gt.id 
FROM #temp t 
JOIN GeometryType gt ON t.geometry_type = gt.name
WHERE t.polygon_wkt IS NOT NULL;

INSERT INTO [Geometry]
SELECT (GEOGRAPHY::STGeomFromText('POINT(' + CAST(t.longitude AS VARCHAR(20)) + ' ' + CAST(t.latitude AS VARCHAR(20)) + ')', 4326)) AS coordinate,
    t.latitude,
    t.longitude,
    l.id,
    w.id
FROM [Location] l 
JOIN #temp t ON l.id = t.id
JOIN WKT w ON t.polygon_wkt = w.value;

INSERT INTO Location_Brand
SELECT DISTINCT l.id, b.id 
FROM #temp t 
INNER JOIN LocationName ln ON t.location_name = ln.name
INNER JOIN Location l ON l.location_name_id = ln.id
INNER JOIN Brand b ON t.brand LIKE CONCAT('%',b.name,'%');

IF @@ERROR <> 0
BEGIN
    ROLLBACK TRANSACTION
END
ELSE
BEGIN
    COMMIT TRANSACTION
END;