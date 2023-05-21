USE [DBCity]
GO

/****** Object:  StoredProcedure [dbo].[FindPOIs]    Script Date: 5/21/2023 10:27:10 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[FindPOIs] 
    @SearchCriteria NVARCHAR(MAX)
AS
BEGIN
    DECLARE @json NVARCHAR(MAX);
    DECLARE @currentLocation GEOGRAPHY;
    SET @currentLocation = GEOGRAPHY::STGeomFromText('POINT(-112.133493 33.568018)', 4326); --Dummy location in Phoenix
    
    -- Parse JSON input parameter
    IF @SearchCriteria IS NOT NULL
    BEGIN
        SELECT @json = @SearchCriteria;
    END
    ELSE
    BEGIN
        SET @json = N'{}'; -- Empty JSON object
    END
    
    DECLARE @country INT,
			@region INT,
			@city VARCHAR(50),
			@latitude DECIMAL(18, 6),
			@longitude DECIMAL(18, 6),
			@radius DECIMAL(18,3),
			@WKTPolygon VARCHAR(MAX),
			@POICategory INT,
			@POIName VARCHAR(50);

	SELECT @country = [value] FROM OPENJSON(@json) WHERE [key] = 'country';
	SELECT @region = [value] FROM OPENJSON(@json) WHERE [key] = 'region';
	SELECT @city = [value] FROM OPENJSON(@json) WHERE [key] = 'city';
	SELECT @latitude = [value] FROM OPENJSON(@json) WHERE [key] = 'latitude'; 
	SELECT @longitude = [value] FROM OPENJSON(@json) WHERE [key] = 'longitude'; 
	SELECT @radius = [value] FROM OPENJSON(@json) WHERE [key] = 'radius'; 
	SELECT @WKTPolygon = [value] FROM OPENJSON(@json) WHERE [key] = 'WKTPolygon';
	SELECT @POICategory = [value] FROM OPENJSON(@json) WHERE [key] = 'category';
	SELECT @POIName = [value] FROM OPENJSON(@json) WHERE [key] = 'name';
	
	--DECLARE @reversedGeography GEOGRAPHY;
	--SET @reversedGeography = GEOGRAPHY::STGeomFromText(@WKTPolygon, 4236).ReorientObject();

	SET @radius = @radius * 1000;

	SELECT DISTINCT
		l.id as Id,
		l.parent_id as [ParentID],
		con.code as [CountryCode],
		r.name as [RegionCode],
		ci.name as [CityName],
		geo.latitude as [Latitude],
		geo.longitude as [Longitude],
		cat.name as [Category],
		scat.name as [SubCategory],
		w.value as [WKTPolygon],
		ln.name as [LocationName],
		pc.code as [PostalCode],
		oh.value as [OperationHours]
	INTO #TempResult -- Store the results in a temporary table
	FROM Location l
	INNER JOIN LocationName ln ON l.location_name_id = ln.id
	INNER JOIN City ci ON l.city_id = ci.id
	INNER JOIN Region r ON ci.region_id = r.id
	INNER JOIN Country con ON r.country_id = con.id
	INNER JOIN [Geometry] geo ON geo.location_id = l.id
	LEFT JOIN WKT w ON geo.wkt_id = w.id
	INNER JOIN GeometryType geot ON geot.id = w.geometry_type_id
	LEFT JOIN OperationsHours oh ON l.operation_hours_id = oh.id
	LEFT JOIN SubCategory scat ON scat.id = l.sub_category_id
	INNER JOIN Category cat ON l.category_id = cat.id
	INNER JOIN PostalCode pc on l.[postal_code_id] = pc.id
	WHERE
		(@SearchCriteria IS NULL AND @currentLocation.STDistance(geo.coordinates) <= 200) OR
		(@SearchCriteria IS NOT NULL AND
		(@country IS NULL OR con.id = @country) AND
		(@region IS NULL OR r.id = @region) AND
		(@city IS NULL OR ci.id = @city) AND
		(@POICategory IS NULL OR cat.id = @POICategory) AND
		(@POIName IS NULL OR ln.name LIKE CONCAT('%',@POIName,'%')) AND
		(@WKTPolygon IS NULL OR geo.coordinates.STIntersects(@WKTPolygon) = 1) AND
		(@latitude IS NULL OR @longitude IS NULL 
		OR
		(GEOGRAPHY::STPointFromText('POINT(' + CAST(@longitude as VARCHAR(20)) + ' ' + CAST(@latitude AS VARCHAR(20)) + ')', 4326))
		.STDistance(geo.coordinates) 
		<= @radius));

	SELECT
    'Feature' AS [type],
    'Point' AS [geometryType],
    (
        SELECT
            'Point' AS [type],
            JSON_QUERY(CONCAT('[', CONVERT(NVARCHAR(MAX), longitude), ',', CONVERT(NVARCHAR(MAX), latitude), ']')) AS [coordinates]
        FROM #TempResult AS T
        WHERE T.Id = L.Id
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS [geometry],
    (
        SELECT
            T.Id AS [id],
            T.ParentID AS [parentId],
            T.CountryCode AS [countryCode],
            T.RegionCode AS [regionCode],
            T.CityName AS [cityName],
            T.Category AS [category],
            ISNULL(T.SubCategory, '') AS [subCategory],
            ISNULL(T.WKTPolygon, '') AS [wktpolygon],
            T.LocationName AS [locationName],
            T.PostalCode AS [postalCode],
            ISNULL(T.OperationHours, '') AS [operationHours]
        FROM #TempResult AS T
        WHERE T.Id = L.Id
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS [properties]
	INTO #TempGeoJsonResult
	FROM #TempResult AS L
	GROUP BY L.Id, L.ParentID, L.Category, L.SubCategory, L.WKTPolygon, L.LocationName, L.PostalCode, L.OperationHours;


	DECLARE @jsonOutput VARCHAR(MAX)

	SELECT @jsonOutput = (
	    SELECT
	    'FeatureCollection' AS [type],
	    JSON_QUERY(
	        (
	            SELECT
	                type AS [type],
	                JSON_QUERY(geometry) AS [geometry],
					 JSON_QUERY(properties) AS [properties]
	            FROM #TempGeoJsonResult
	            FOR JSON PATH
	        )
	    ) AS [features]
	FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
	)
	--SELECT @jsonOutput AS JSONOutput
	SELECT COMPRESS(@jsonOutput) AS JSONOutput

	DROP TABLE IF EXISTS #TempGeoJsonResult
	DROP TABLE IF EXISTS #TempResult
END


GO


