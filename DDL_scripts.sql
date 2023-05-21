CREATE TABLE [Category] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(100) NOT NULL
);

CREATE TABLE [Brand] (
	[id] NVARCHAR(41) PRIMARY KEY,
	[name] NVARCHAR(100)
);

CREATE TABLE [SubCategory] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(100),
	[category_id] INT,
	FOREIGN KEY ([category_id]) REFERENCES [Category] ([id])
);

CREATE TABLE [Tag] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(100)
);

CREATE TABLE [Country] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(255) NOT NULL,
	[code] NVARCHAR(2) NOT NULL,
	[language] NVARCHAR(3) NOT NULL
);

CREATE TABLE [LocationName] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(500) NULL
);

CREATE TABLE [OperationsHours] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[value] NVARCHAR(1000) NOT NULL
);

CREATE TABLE [GeometryType] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(50) NOT NULL
);

CREATE TABLE [WKT] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[value] NVARCHAR(MAX) NOT NULL,
	[geometry_type_id] INT NOT NULL,
	FOREIGN KEY ([geometry_type_id]) REFERENCES [GeometryType] ([id])
);

CREATE TABLE [Region] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(255) NOT NULL,
	[country_id] INT NOT NULL,
	FOREIGN KEY ([country_id]) REFERENCES [Country] ([id])
);

CREATE TABLE [City] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[name] NVARCHAR(255) NOT NULL,
	[region_id] INT NOT NULL,
	FOREIGN KEY ([region_id]) REFERENCES [Region] ([id])
);

CREATE TABLE [PostalCode] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[code] NVARCHAR(6) NOT NULL,
	[city_id] INT NOT NULL,
	FOREIGN KEY ([city_id]) REFERENCES [City] ([id])
);

CREATE TABLE [Location] (
	[id] NVARCHAR(20) PRIMARY KEY,
	[parent_id] NVARCHAR(20) NULL,
	[location_name_id] INT NOT NULL,
	[operation_hours_id] INT NULL,
	[category_id] INT NULL,
	[sub_category_id] INT NULL,
	[city_id] INT NOT NULL,
	[postal_code_id] INT NOT NULL,
	FOREIGN KEY ([location_name_id]) REFERENCES [LocationName] ([id]),
	FOREIGN KEY ([operation_hours_id]) REFERENCES [OperationsHours] ([id]),
	FOREIGN KEY ([category_id]) REFERENCES [Category] ([id]),
	FOREIGN KEY ([sub_category_id]) REFERENCES [SubCategory] ([id]),
	FOREIGN KEY ([parent_id]) REFERENCES [Location] ([id]),
	FOREIGN KEY ([city_id]) REFERENCES [City] ([id]),
	FOREIGN KEY ([postal_code_id]) REFERENCES [PostalCode] ([id])
);

CREATE TABLE [Location_Brand] (
	[location_id] NVARCHAR(20),
	[brand_id] NVARCHAR(41),
	PRIMARY KEY ([location_id], [brand_id]),
	FOREIGN KEY ([location_id]) REFERENCES [Location] ([id]),
	FOREIGN KEY ([brand_id]) REFERENCES [Brand] ([id])
);

CREATE TABLE [Geometry] (
	[id] INT IDENTITY(1,1) PRIMARY KEY,
	[coordinates] GEOGRAPHY NOT NULL,
	[latitude] DECIMAL(18,6) NOT NULL,
	[longitude] DECIMAL(18,6) NOT NULL,
	[location_id] NVARCHAR(20) NOT NULL,
	[wkt_id] INT NOT NULL,
	FOREIGN KEY ([location_id]) REFERENCES [Location] ([id]),
	FOREIGN KEY ([wkt_id]) REFERENCES [WKT] ([id])
);

CREATE TABLE [Category_Tag] (
	[category_id] INT,
	[tag_id] INT,
	PRIMARY KEY ([category_id], [tag_id]),
	FOREIGN KEY ([category_id]) REFERENCES [Category] ([id]),
	FOREIGN KEY ([tag_id]) REFERENCES [Tag] ([id])
);

-- Index for LocationName.name
CREATE INDEX idx_LocationName_name ON LocationName (name);

-- Index for Location.location_name_id
CREATE INDEX idx_Location_location_name_id ON Location (location_name_id);

-- Index for Brand.name
CREATE INDEX idx_Brand_name ON Brand (name);

-- Create a spatial index on the "coordinates" column in the "Geometry" table
CREATE SPATIAL INDEX IX_Geometry_Coordinates
ON Geometry(coordinates)
USING GEOGRAPHY_GRID
WITH (GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM), CELLS_PER_OBJECT = 16);