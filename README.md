# Points Of Interests SQL

This repository contains scripts and backups for a database.

## Structure of the Repository

The repository is organized into the following sections:

1. **DDL_scripts**: This directory contains scripts for creating tables and indexes in the database.

2. **DML_scripts**: This directory contains scripts for loading data into tables and a stored procedure for finding Points of Interest based on specific criteria.

3. **Database_Backups**: This directory contains backups of the database.

## How to Import the Backup

To import the backup into your database, follow these steps:

1. Download the latest backup file from the **Database_Backups** directory.

2. Open your database management system.

3. Create a new database or select the existing database where you want to import the backup.

4. Locate the import feature in your database management system. This could be a command-line tool, a graphical user interface, or a specific command in your database software.

5. Use the import feature to select the downloaded backup file and import it into your database.

6. Once the import process is complete, you should have the database with the backed-up data.

## Running Scripts Manually

If you prefer to run the scripts manually instead of using the backup, follow these steps:

1. Open your database management system.

2. Create a new database or select the existing database where you want to run the scripts.

3. Open the **DDL_scripts** directory and execute the scripts in the order of their dependencies. This will create the necessary tables and indexes.

4. Open the **DML_scripts** directory and execute the data loading scripts to populate the tables.

5. If you want to use the stored procedure for finding Points of Interest, execute the stored procedure script.

6. The scripts should now be executed, and you can use the database according to your requirements.

## How to Test

To test the functionality of the stored procedure [dbo].[FindPOIs], you can use the following commands:

### Case 1: No Search Criteria

If you don't specify search criteria parameters, stored procedure will retrieve all Points of Interest (POIs) within 200 meters from a dummy location in Phoenix ('POINT(-112.133493 33.568018)'), execute the following command:

```sql
EXEC [dbo].[FindPOIs]
    @SearchCriteria = NULL
```
    
### Case 2: Specifying Search Criteria

To search for POIs based on specific criteria, you can provide the search criteria parameters in JSON format. Here's an example command:
```
EXEC [dbo].[FindPOIs]
    @SearchCriteria = '{
        "country": 1,
        "region": 2,
        "city": 1,
        "latitude": 33.503145,
        "longitude": -112.14341,
        "radius": 1.2,
        "WKTPolygon":"POLYGON ((-112.14368581999997 33.50345166000005, -112.14361815399997 33.503393430000074, -112.14356011499996 33.503439472000025, -112.14347254799998 33.50336411600006, -112.14352644199994 33.503321363000055, -112.14349061799999 33.503290535000076, -112.14336210399995 33.503392484000074, -112.14329443799994 33.50333425500003, -112.14342709899995 33.503229017000024, -112.14335943399999 33.503170787000045, -112.14316873399997 33.503322067000056, -112.14306922699996 33.50323643400003, -112.14336771199999 33.50299964900006, -112.14391699699996 33.50347233700006, -112.14376360799997 33.50359401900005, -112.14364021799997 33.50348783600003, -112.14368581999997 33.50345166000005))", "category": "1",
        "name":"Grand"
  }'
```

This command:
```
EXEC [dbo].[FindPOIs]
    @SearchCriteria = '{
        "country": 1,
        "region": 1,
        "WKTPolygon":"POLYGON ((-112.14368581999997 33.50345166000005, -112.14361815399997 33.503393430000074, -112.14356011499996 33.503439472000025, -112.14347254799998 33.50336411600006, -112.14352644199994 33.503321363000055, -112.14349061799999 33.503290535000076, -112.14336210399995 33.503392484000074, -112.14329443799994 33.50333425500003, -112.14342709899995 33.503229017000024, -112.14335943399999 33.503170787000045, -112.14316873399997 33.503322067000056, -112.14306922699996 33.50323643400003, -112.14336771199999 33.50299964900006, -112.14391699699996 33.50347233700006, -112.14376360799997 33.50359401900005, -112.14364021799997 33.50348783600003, -112.14368581999997 33.50345166000005))", "category": "1"
  }'
```
should return these GeoJSON(before compression):
```
{
    "type": "FeatureCollection",
    "features": [
        {
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [
                    -112.015837,
                    33.423338
                ]
            },
            "properties": {
                "id": "zzw-222@8ts-zhq-wp9",
                "parentId": "zzw-222@8ts-zhq-73q",
                "countryCode": "US",
                "regionCode": "AZ",
                "cityName": "Phoenix",
                "category": "Support Activities for Water Transportation",
                "subCategory": "Port and Harbor Operations",
                "wktpolygon": "POLYGON ((-112.01600054201394 33.4248085, -112.01555396814521 33.424808500000005, -112.01555405199997 33.424479665000035, -112.01552157399999 33.42447965900004, -112.01552161399997 33.42432518800007, -112.01556221099997 33.42432519500005, -112.01556229999994 33.42398267400006, -112.01552982199996 33.423982668000065, -112.01552986099995 33.423828198000024, -112.01557045799996 33.423828204000074, -112.01557067199997 33.42299540600004, -112.01553819399999 33.42299539900006, -112.01553823199998 33.42284764500005, -112.01557070899997 33.42284765100004, -112.01557075899996 33.42265288300007, -112.01600108199995 33.42265295800007, -112.01600054201394 33.4248085))",
                "locationName": "Ports of Entry Phoenix Arizona",
                "postalCode": "85034",
                "operationHours": ""
            }
        }
    ]
}
```

## Important notes:

Please note that executing the stored procedure will return JSON data in a compressed format, which needs to be decompressed and stored locally. However, decompression and local storage are considered as out of the scope of this task.
