Oil and Gas Infrastructure Mapping (OGIM) Database v2.7
Authors: Mads O’Brien, Mark Omara, Anthony Himmelberger, Ritesh Gautam
README version: March 28, 2025
Database Filename: OGIM_v2.7.gpkg (generated on 2025-02-14)


Overview
The Oil and Gas Infrastructure Mapping (OGIM) database is developed by Environmental
Defense Fund (www.edf.org) in support of the MethaneSAT satellite project managed by
MethaneSAT, LLC (www.methanesat.org). MethaneSAT, LLC is a wholly-owned subsidiary
of Environmental Defense Fund (EDF). The primary objective of developing a global,
granular oil and gas (O&G) infrastructure database is to support MethaneSAT’s emission
quantification, source characterization, and subsequent scientific- or advocacy-relevant
analyses of methane emissions from the global oil and gas sector. This database can be
used to support other related research works on global O&G methane emission
assessment and source characterization.
This document describes a version of the OGIM (v2.7) based solely upon publicly
available source datasets. The spatial coverage of OGIM v2.7 includes six continents and
152 countries. Oil and gas infrastructure records were obtained via a combination of
manual and semi-automated search of O&G datasets in the public domain. We compiled,
cleaned, and integrated 188 O&G geospatial datasets, which were combined within one
standard data schema and coordinate reference system.
An in-depth description of the methods for the global OGIM database development, and
a detailed discussion of the key applications of this database, can be found in the below-
mentioned Earth System Science Data article. Note that the content of the v2.7 database
accompanying this README is an updated version of the OGIM GeoPackage available on
ESSD’s website. Please cite this article when using the database in presentations and/or
any publications:
       Omara, M., Gautam, R., O'Brien, M. A., Himmelberger, A., Franco, A., Meisenhelder, K.,
       Hauser, G., Lyon, D. R., Chulakadabba, A., Miller, C. C., Franklin, J., Wofsy, S. C., and
       Hamburg, S. P.: Developing a spatially explicit global oil and gas infrastructure database
       for characterizing methane emission sources at high resolution, Earth Syst. Sci. Data, 15,
       3761–3790, https://doi.org/10.5194/essd-15-3761-2023, 2023.




                                              [1]
Changes since v2.5.1
Version 2.5.1 aimed to incorporate the latest published O&G data globally as of January
2024, with North American datasets updated as of April 2024. For v2.7, the authors
revisited every one of OGIM’s data sources and incorporated the latest information
available as of February 2025. About 42% of all well records in v2.7 were published by
their original source between 1 February and 10 February 2025. About 23% of all pipeline
records in v2.7 were published between 1 February and 10 February 2025, as well. Taking
all 14 remaining infrastructure categories together, about 44% of the records in these
categories were published between 1 February and 10 February 2025.

A number of new data sets were added to v2.7, including:
   • Nonvertical wells in Saskatchewan
   • Argentina pumping stations
   • Nebraska wells
   • South Dakota wells
   • United States above ground LNG storage facilities
   • State-specific wells in Western Australia, South Australia, and Queensland, to
      complement offshore and national wells reported by Australia’s National Offshore
      Petroleum Titles Administrator (NOPTA)

For some regions and infrastructure categories, the authors replaced the underlying data
source with a more frequently updated and/or more attribute-rich one. These include:
    • Tennessee wells
    • Missouri wells
    • Oklahoma wells
    • Colombia wells
    • Germany wells (specifically Lower Saxony)
    • Netherlands O&G fields and offshore platforms
    • United Kingdom offshore platforms and petroleum terminals
    • United States offshore platforms

Other Updates
   • Bug fix: Turkey refineries were erroneously excluded in v2.5.1; the six refineries
       are now present.
   • Data availability: Includes VIIRS flaring detections from the year 2023.
   • Quality assurance: Additional duplicate records were removed.

Known Issues
   • Various records in Argentina contain improperly encoded characters. Our team
      has determined this is due to corrupted information in the original dataset, and
      we are still working on resolving the issue.



                                           [2]
Database structure
OGIM v2.7 is a collection of data tables within a GeoPackage, an open-source geospatial
database format. Each data table or “layer” of the GeoPackage, listed in Table 1,
represents an infrastructure category that plays a major role in the O&G sector. All
records in the database have an associated spatial point location, except for O&G
pipelines (geometry type: LineString) and O&G fields, license blocks, and basins
(geometry type: Polygon). These data have been transformed to a common spatial
reference system (WGS 1984, EPSG:4326). All GeoPackage layer names use underscores
to separate words.
Table 1: List of the geospatial data layers (representing O&G infrastructure categories) in the OGIM database.

                        Geopackage layer name                     # of variables        # of records
                         Crude_Oil_Refineries                            22                  692
                     Equipment_and_Components                            19                98,047
                      Gathering_and_Processing                           26                10,396
                        Injection_and_Disposal                           24                14,209
                             LNG_Facilities                              24                  547
                 Natural_Gas_Compressor_Stations                         26                12,156
                   Natural_Gas_Flaring_Detections                        22                10,233
                           Offshore_Platforms                            19                 3,903
                      Oil_Natural_Gas_Pipelines                          24              1,858,109
                     Oil_and_Natural_Gas_Basins                          13                  709
                     Oil_and_Natural_Gas_Fields                          13                17,742
               Oil_and_Natural_Gas_License_Blocks                        13                 2,833
                      Oil_and_Natural_Gas_Wells                          20              4,537,369
                         Petroleum_Terminals                             24                 3,661
                             Stations_Other                              19                 8,468
                              Tank_Battery                               24               132,220



In addition to the 16 layers in the table above, the GeoPackage includes a table layer (no
geometry information) called “Data_Catalog.” Each unique publication or web portal
used as a source during OGIM database development is assigned a numeric Source
Reference ID, or ‘SRC_ID’, and is listed in the Data Catalog alongside some metadata
information. Each record in the final OGIM database has a 'SRC_REF_ID' attribute that
can be used to join the record to its original source information in the Data Catalog,
making it easy for a user to visit the original source(s) of the record if desired.
All geospatial data were pre-processed, analyzed, assembled, and tested using open-
source software, including but not limited to Python v3.7 and QGIS v3.24. OGIM v2.7
uses UTF-8 encoding.

                                                         [3]
Data attributes
A full description of the database schema used in all layers can be found in Supplement 1:
OGIM v2.7 Database Schema. A full description of the schema used in the “Data Catalog”
layer can be found in Supplement 2: OGIM v2.7 Data Catalog Schema. Both supplements
are provided with this README.
Some additional notes on data attributes:

   •   Unique IDs: Each record in each infrastructure layer is assigned a unique
       numerical identifier (‘OGIM_ID’). The IDs do not repeat between data layers. In
       addition, each record has an assigned ‘SRC_REF_ID’, which identifies the original
       data source in a separate “Data Catalog” layer.
   •   Missing values (i.e., values missing or not reported in the original source) are
       handled by assigning “N/A” to string attributes, -999 to numerical attributes, and
       a generic date of “1900-01-01” to date/datetime attributes.
   •   For date attributes (i.e., ‘SRC_DATE’, ‘INSTALL_DATE’, ‘SPUD_DATE’,
       ‘COMP_DATE’), if an incomplete date is recorded in the original data source, we
       fill out the rest of the date with ‘01’. For example, if a data source indicates a well
       was spudded in May 2019, with no day of the month provided, we record this
       date as “2019-05-01”. If a source indicates a facility was installed in the year 2017,
       we record this date as “2017-01-01.”
   •   Operator names have not been altered in any way from the original source of
       data and are assumed to be accurate as of the original source’s publication date.
   •   Non-English source data: Some values from non-English datasets (such as status,
       facility type, and drilling direction) were translated to English before inclusion in
       OGIM. However, place names, facility names, and operator names were kept in
       their original language.




                                            [4]
                     Table 2: Sample record from OGIM's Oil and Natural Gas Wells layer.

                      Attribute name           Value
                      OGIM_ID                  2081355
                      CATEGORY                 OIL AND NATURAL GAS WELLS
                      REGION                   CENTRAL AND SOUTH AMERICA
                      COUNTRY                  ARGENTINA
                      STATE_PROV               SANTA CRUZ
                      SRC_REF_ID               105
                      SRC_DATE                 2025-02-04
                      ON_OFFSHORE              ONSHORE
                      FAC_NAME                 YPF.SC.EG-556
                      FAC_ID                   97315
                      FAC_TYPE                 OIL
                      DRILL_TYPE               CONVENTIONAL
                      SPUD_DATE                2003-02-15
                      COMP_DATE                2003-03-10
                      FAC_STATUS               ACTIVE
                      OGIM_STATUS              PRODUCING
                      OPERATOR                 YPF S.A.
                      LATITUDE                 -46.33622
                      LONGITUDE                -69.19831
                      geometry                 POINT (-69.19831 -46.33622)




Descriptions of infrastructure categories in v2.7
Oil and Natural Gas Wells: contains point locations of O&G wellheads. Wellheads are located on
well sites and each well site may have one or multiple wellheads. Wellheads may produce oil, gas,
or both. The facility status attribute indicates the operating status of each wellhead. Other well
types that assist with O&G operations (e.g., water injection, salt injection) are included in this
layer, and are indicated by their FAC_TYPE attribute where available. Since this well dataset is
intended for methane emission analysis and visualization of O&G infrastructure locations, we did
not include locations that states reported as stratigraphic test wells. We also removed locations
of wells that were proposed but never materialized (cancelled permits that were never drilled, for
example).

Natural Gas Compressor Stations: natural gas compressor stations regulate the flow and pressure
of natural gas for pipeline transportation of natural gas (e.g., within and across states). Often, but
not always, these stations are located at points along a transportation pipeline.

Gathering and Processing: facilities designed to “gather” and treat or process O&G products, for
example, to produce pipeline-quality natural gas, or remove impurities and other entrained



                                                     [5]
hydrocarbons in the oil and gas stream. Examples include natural gas processing plants, central
gathering facilities, and crude oil treatment facilities.

Tank Battery: a system or group of storage tanks receiving oil and gas produced from one or
multiple wellheads. May be located at a well site or at a major O&G gathering/processing facility
(e.g., central gathering facility, compressor station and processing plant).
Please note that many states and provinces do not publish locations of tank batteries; for this
layer in particular, lack of tanks in O&G producing regions most likely implies a gap in reporting
rather than the absence of infrastructure.

Offshore Platforms: offshore production, gathering, and processing facilities, which could include
an offshore drilling platform (a rig positioned above an offshore well), or a central processing
platform (where hydrocarbons are processed or refined offshore before transit elsewhere).
Offshore platforms may produce oil, gas, or both.

LNG Facilities: export and import liquified natural gas (LNG) facilities that treat and condense
natural gas into a liquid form to facilitate the material’s transport or sale. Often, but not always,
these facilities are found near bodies of water and handle LNG transported by sea.

Crude Oil Refineries: crude oil refineries convert crude oil and other hydrocarbons into useful
petroleum-based products, including, for example, production of transportation fuels, such as
diesel and gasoline.

Petroleum Terminals: a facility that stores crude oil and refined petroleum products. Often, but
not always, found co-located with a marine port or at the start of a pipeline system. Can be
collocated with refineries, LNG facilities, and other major O&G facilities where O&G processing
occurs.

Injection and Disposal: facilities used to safely dispose O&G waste, for example, via injection into
deep, confined rock formations.

Equipment and Components: locations of O&G equipment and components at larger facilities
(e.g., valves and dehydrators).

Stations – Other: includes some “minor” O&G facility types, such as metering and regulating
stations, POL (petroleum, oil, and lubricants) pumping stations, and LACT (lease automatic
custody transfer units). These types of facilities may be collocated with other major O&G
gathering and processing facilities, e.g., compressor stations and processing plants.

Natural Gas Flaring Detections: locations of a facility or cluster of facilities where natural gas
flaring has been detected based on observations from the Visible Infrared Imaging Radiometer
Suite (VIIRS) satellite instrument. Gas flaring can occur at a wide variety of oil and gas facilities,
including well sites, offshore platforms, compressor stations, processing plants, refineries and
LNG facilities. The layer includes flaring detections and estimated flaring volumes for 2023. The
Earth Observation Group at the Colorado School of Mines has granted EDF permission to include
these 2023 data in OGIM.




                                                 [6]
Oil and Natural Gas Pipelines: pipelines that transport crude oil or natural gas.

Oil and Natural Gas Fields: a surface area above a particular pool of oil/gas reserves, where
exploration or extraction occurs.

Oil and Natural Gas License Blocks: a surface area where a company or joint venture has been
given the rights to explore or extract O&G resources.

Oil and Natural Gas Basins: a geological province, whose bounds are usually defined by the extent
of certain rock formations above or below the surface.




Acknowledgments
We thank Kaiya Weatherby at Environmental Defense Fund for his help in quality-
assuring the latest version of the database.


Database limitations
The database is based on public information which can be of variable spatial quality,
update frequency, and richness of feature attributes depending on the data source.
While we have made substantial improvement to the database in this version, we expect
to further refine and QA/QC the database in future releases, especially as new data
sources and updates to existing sources become available.



For comments, questions, or feedback, please contact:

Mads O’Brien (maobrien@methanesat.org) and Mark Omara (momara@edf.org)




                                                [7]
                                                                  Supplement 1: OGIM v2.7 Database Schema

Table A: Attributes present in all layers
                                        Allow                                                    Valid values and/or example
Attribute name            Data type     nulls?   Description                                     values                              Notes

                                                                                                 valid: 'CRUDE OIL REFINERIES';
                                                                                                 'EQUIPMENT AND COMPONENTS';
                                                                                                 'GATHERING AND PROCESSING';
                                                                                                 'INJECTION AND DISPOSAL'; 'LNG
                                                                                                 FACILITIES'; 'NATURAL GAS
                                                                                                 COMPRESSOR STATIONS'; 'NATURAL
                                                                                                 GAS FLARING DETECTIONS';
                                                 Category of O&G infrastructure to which the                                        Within a geopackage layer, all values for
CATEGORY                  string        no                                                       'OFFSHORE PLATFORMS'; 'OIL AND
                                                 record belongs.                                                                    CATEGORY should be the same.
                                                                                                 NATURAL GAS BASINS'; 'OIL AND
                                                                                                 NATURAL GAS FIELDS'; 'OIL AND
                                                                                                 NATURAL GAS LICENSE BLOCKS'; 'OIL
                                                                                                 AND NATURAL GAS PIPELINES'; 'OIL
                                                                                                 AND NATURAL GAS WELLS';
                                                                                                 'PETROLEUM TERMINALS'; 'STATIONS -
                                                                                                 OTHER'; 'TANK BATTERIES'

                                                                                                                                     Only LineString and Polygon features may fall in 2+
                                                 Country in which the record resides. Where
                                                                                                 ex: 'GERMANY'; 'AFGHANISTAN,        countries; in these cases, COUNTRY field contains
COUNTRY                   string        no       possible, country name matches the UN
                                                                                                 TURKMENISTAN'                       a comma-separated list of these countries in
                                                 Member State list.
                                                                                                                                     alphabetical order.
                                                 Unique identifier for each record in the
OGIM_ID                   integer       no       geopackage. Values do not repeat across
                                                 infrastructure categories.

                                                                                                                                     Only LineString and Polygon features may fall both
                                                 Indicates whether the record lies onshore,      valid: 'ONSHORE'; 'OFFSHORE';
ON_OFFSHORE               string        no                                                                                           on and offshore, so only these geometries may
                                                 offshore, or both.                              'ONSHORE, OFFSHORE'
                                                                                                                                     have the value 'ONSHORE, OFFSHORE'.

                                                                                                 valid: 'AFRICA', 'ASIA PACIFIC',
                                                 World region in which the record lies. When                                         It is possible for line and polygon features to have
                                                                                                 'CENTRAL AND SOUTH AMERICA',
REGION                    string        yes      possible, region aligns with the IEA's Energy                                       a value of N/A if they pass through multiple
                                                                                                 'EURASIA', 'EUROPE', 'MIDDLE
                                                 Region classifications.                                                             countries/regions.
                                                                                                 EAST', 'NORTH AMERICA', 'N/A'




                                                                               Supplement page 1 of 8
                                               Supplement 1: OGIM v2.7 Database Schema

                                                                                                            If a record's attributes were derived from 2+
                              Publication date of the record's original data
SRC_DATE     string     no                                                   ex: '2024-06-01'               different sources (see below), the most recent
                              source; YYYY-MM-DD format.
                                                                                                            source date is listed in this field.
                                                                                                            Records that list multiple SRC_REF_IDs separated
                                                                                                            by a comma (such as '89,92') indicate that
                              ID number(s) linking the record to its
                                                                                                            different attributes of that record were obtained
SRC_REF_ID   string     no    corresponding source in the "Data_Catalog"    ex: '22'; '89,92'
                                                                                                            from different sources. For example, a record's
                              table.
                                                                                                            location may have come from SRC_ID 89, but
                                                                                                            facility status came from SRC_ID 92.
                                                                                                            LineString or Polygon features that intersect a very
                                                                                                            large number of states/provinces may simply list a
STATE_PROV   string     yes   State or province in which the record resides. ex: 'TEXAS'; 'ALBERTA'
                                                                                                            value of 'N/A', to prevent excessively long
                                                                                                            attribute values.
                              Vertices of the feature's geometry.
                                                                            ex: 'POINT (67.42377999999999
geometry     geometry   no    Formatted as well-known text (WKT)
                                                                            37.21161)'
                              representations of the geometries.




                                                            Supplement page 2 of 8
                                                                      Supplement 1: OGIM v2.7 Database Schema

Table B: Attributes present in all well + infrastructure layers
                                        Allow                                                      Valid values and/or example
Attribute name            Data type     nulls?      Description                                    values                              Notes
                                                    Unique ID used by the original source agency ex: 'BGBR0230'; '126162'; '5609/10-
FAC_ID                    string        yes
                                                    to identify the infrastructure asset.        01'
FAC_NAME                  string        yes         Name of the infrastructure asset.

                                                    Operational status of the infrastructure asset, ex: 'ACTIVE'; 'SUSPENDED';         FAC_STATUS of "N/A" cannot be assumed to mean
FAC_STATUS                string        yes
                                                    according to the original source.               'TEMPORARILY CLOSED'               active or inactive.
                                                                                                   ex: ''EXPORT FACILITY"; "NGL
FAC_TYPE                  string        yes         Detailed information on type of facility.
                                                                                                   FRACTIONATION FACILITY"
                                                                                                                                       Some data sources only included an installation
                                                                                                                                       year, or a month-year combination. These values
                                                    Date the facility or asset was installed; YYYY-                                    appear with their month or date value filled with
INSTL_DATE *              string        yes                                                         ex: '1994-02-17'
                                                    MM-DD format.                                                                      '01'. For example, if we only know a facility was
                                                                                                                                       installed in 2012, the INSTL_DATE would appear
                                                                                                                                       '2012-01-01'.

LATITUDE                  float         no          Latitude of Point features in decimal degrees. ex: 30.11438
                                                    Longitude of Point features in decimal
LONGITUDE                 float         no                                                         ex: -93.29659
                                                    degrees.
                                                                                                valid: 'PERMITTING'; 'UNDER
                                                                                                CONSTRUCTION'; 'OPERATIONAL';
                                                    Standardized version of FAC_STATUS, created 'PROPOSED'; 'DRILLING';
                                                    by the OGIM authors to "bin" statuses       'COMPLETED'; 'PRODUCING';
OGIM_STATUS               string        yes
                                                    reported by the original source into        'INACTIVE'; 'ABANDONED';
                                                    categories.                                 'INJECTING'; 'STORAGE,
                                                                                                MAINTENACE, OR OBSERVATION';
                                                                                                'OTHER'
                                                                                                   ex: 'YSUR ENERGÍA ARGENTINA         No modifications have been made to standardize
                                                    Name of the asset's operator, according to
OPERATOR                  string        yes                                                        S.R.L.'; 'PETROBRAS'; 'DCP          operator names or associate subsidiaries with
                                                    the orginal source at time of publication.
                                                                                                   MIDSTREAM, LP'                      parent companies.

* = attribute not present for wells




                                                                                   Supplement page 3 of 8
                                                                       Supplement 1: OGIM v2.7 Database Schema

Table C: Attributes present in wells layer only
                                        Allow                                                        Valid values and/or example
Attribute name           Data type      nulls?      Description                                      values                          Notes
                                                    Date that well construction was completed;
COMP_DATE                 string        yes                                                          ex: '2019-12-13'
                                                    YYYY-MM-DD format.
                                                                                                                                     Conventional' indicates a vertical well;
                                                                                                     ex: 'HORIZONTAL'; 'VERTICAL';
DRILL_TYPE                string        yes         Drilling direction of the well.                                                  'Unconventional' indicates a horizontal or
                                                                                                     'DIRECTIONAL'; 'CONVENTIONAL'
                                                                                                                                     hydraulic fracturing well.
                                                    Date that well was first spudded (i.e., drilling
SPUD_DATE                 string        yes                                                          ex:' 2019-04-11'
                                                    began); YYYY-MM-DD format.

Table D: Attributes present in pipelines only
                                       Allow                                                         Valid values and/or example
Attribute name           Data type     nulls?       Description                                      values                          Notes
PIPE_DIAMETER_MM float                 yes          Pipeline diameter in millimeters.                ex: 88, 114
                                                                                                                                     Pipeline length is calculated for each feature in GIS
PIPE_LENGTH_KM            float         no          Length of pipeline feature in kilometers.        ex: 4.45; 90.4; 1130            by the OGIM authors, even if the original data
                                                                                                                                     source reports a length.
                                                                                                     ex: 'STEEL'; 'POLYETHYLENE';
PIPE_MATERIAL             float         yes         Material that pipeline is made of.               'CARBON STEEL 5L GRADE X 65';
                                                                                                     'ASTM A-106 GR.B'

Table E: Attributes present in basins, fields, and license blocks layers only
                                         Allow                                                       Valid values and/or example
Attribute name           Data type       nulls?      Description                                     values                          Notes
NAME                      string        yes         The name of the basin, field, or license block. ex: 'PERMIAN'
                                                                                                                                     Area is calculated for each feature in GIS by the
AREA_KM2                  float         no          Area of polygon in sq. kilometers.               ex: 37200; 186000               OGIM authors, even if the original data source
                                                                                                                                     reports an area.
                                                                                                     ex: 'OIL'; 'OIL AND GAS';
                                                    Hydrocarbon(s) produced by the reservoir,
                                                                                                     'CONDENSATE'; 'EXPLORATION
RESERVOIR_TYPE            string        yes         OR the phase of production the reservoir is
                                                                                                     AND EXPLOITATION'; 'COALBED
                                                    in.
                                                                                                     METHANE'




                                                                                      Supplement page 4 of 8
                                                                   Supplement 1: OGIM v2.7 Database Schema

Table F: Attributes present in flaring detections only
                                        Allow                                                   Valid values and/or example
Attribute name           Data type      nulls?     Description                                  values                          Notes
AVERAGE_FLARE_TEMP
                         integer        no         Average flare temperature in Kelvin.         ex: 1020, 2119
_K
DAYS_CLEAR_OBSERVA                                 Number of clear days for which flares were
                         integer        no                                                      ex: 123, 381
TIONS                                              detected.
FLARE_YEAR               integer        no         Year in which detections occurred.           valid: 2023
                                                   Estimated volume of gas flared in million
GAS_FLARED_MMCF          float          no
                                                   cubic feet per year.
                                                  Oil and gas industry segment to which the     valid: 'GAS DOWNSTREAM'; 'OIL
SEGMENT_TYPE             string       yes
                                                  flaring detection belongs.                    DOWNSTREAM'; 'UPSTREAM'




                                                                                Supplement page 5 of 8
                                                                    Supplement 1: OGIM v2.7 Database Schema

Table H: Additional attributes in infrastructure layers
                                       Allow                                                       In which layer(s) is attribute
Attribute name    Data type            nulls?      Description                                     present?
GAS_CAPACITY_MMCF                                  Facility capacity for natural gas, in million
                  float                yes                                                         CS, GP, ID, LNG, PL, TM
D                                                  cubic ft. per day.
GAS_THROUGHPUT_M                                   Facility througput for natural gas, in million
                  float                yes                                                         CS, GP, ID, LNG, PL, TM
MCFD                                               cubic ft. per day.
                                                   Facility capacity for O&G liquids, in barrels
LIQ_CAPACITY_BPD         float         yes                                                         CS, GP, ID, LNG, PL, R, TM
                                                   per day.
LIQ_THROUGHPUT_BP                                  Facility throughput for O&G liquids, in barrels
                  float                yes                                                         CS, GP, ID, LNG, PF, PL, R, TM
D                                                  per day.
NUM_STORAGE_TANKS integer              yes         Number of storage tanks at the facility.        CS, GP, ID, LNG, PF, R, TM
                                                   Number of compressor units present at
NUM_COMPR_UNITS          integer       yes                                                         CS, GP, TM
                                                   facility.
SITE_HP                  float         yes         Horsepower of the facility.                     CS, GP
                                                   Hydrocarbon(s) contained in the
COMMODITY                string        yes                                                         PL, SO, TM
                                                   infrastructure.

Key for Table H:
CS = Compressor Stations
GP = Gathering and Processing
ID = Injection and Disposal
LNG = Liquified Natural Gas Facilities
PL = Pipelines
R = Refineries
SO = Stations (Other)
TM = Petroleum Terminals




                                                                                 Supplement page 6 of 8
                                  Supplement 2: OGIM v2.7 Data Catalog Schema

Table Z: Attributes present in the Data Catalog layer
                                   Allow                                                   Valid values and/or example
Attribute name         Data type nulls? Description                                        values
                                            Identification number unique to the particular
SRC_ID                 integer     no
                                            data source.
                                            URL to the webpage that describes the data and
SRC_URL                string      no
                                            offers it for download.
                                                                                                 ex: 'New Zealand Petroleum
SRC_NAME             string      no       Source agency or name (written out fully).             & Minerals'; 'Ministero della
                                                                                                 transizione ecologic'

                                          Optional short-name for source; may be an
                                                                                                 ex: 'NZPAM';
SRC_ALIAS            string      yes      abbreviation of the source agency, or the
                                                                                                 '@jesse_hamlin'; 'USGS'
                                          name/username of the original data author.
                                                                                                 valid: 'Academia', 'ArcGIS
                                          General categorization of the source type, as          Online', 'Company', 'Data
SRC_TYPE             string      no
                                          determined by OGIM team.                               Vendor', 'Government',
                                                                                                 'NGO', 'OGInfra.com'
                                                                                                 valid: integers 1900 - 2024
SRC_YEAR             integer     no       Year that source was published.
                                                                                                 inclusive
SRC_MNTH             integer     no       Month that source was published.                       valid: integers 1 - 12 inclusive

PUB_PRIV             string      no       Public availability of data.                           valid: 'Public'; 'Proprietary'
                                          Does the original data source report O&G
PROD_DATA            boolean     no                                                              valid: 0,1
                                          production values?
                                                                                                 valid: 'Annually', 'Quarterly';
                                          Frequency with which the source is usually             'Monthly', 'Weekly'; 'Daily';
UPDATE_FREQ          string      no
                                          updated.                                               'Irregularly'; 'One-Time';
                                                                                                 'Uncertain'
                                          Date on which an EDF analyst last visited the
LASTVISIT            string      no                                                              ex: '2024-12-13'
                                          source URL; YYYY-MM-DD format.
                                                                                                 valid: 'Africa'; 'Asia'; 'Central
                                                                                                 Asia'; 'Europe'; 'Global';
REGION               string      no       Region in which data lies.                             'Middle East'; 'North
                                                                                                 America'; 'South America';
                                                                                                 'Oceania'; 'Various'
COUNTRY              string      yes      If applicable, country in which data lies.             ex: 'Argentina'; 'Various'
                                                                                                 ex: 'Various'; 'Sub-national';
STATE_PROV           string      yes      If applicable, state or province in which data lies.
                                                                                                 'Kentucky'; 'Alberta'

NOTES                string      yes      Internal notes about the source or its contents.
                                          Does this data source contain any records that
HAS_WELLS            boolean     no       are included in the Oil and Natural Gas Wells          valid: 0, 1
                                          layer?
                                          Does this data source contain any records that
HAS_PLATFORMS        boolean     no                                                              valid: 0, 1
                                          are included in the Offshore Platforms layer?




                                                Supplement page 7 of 8
                           Supplement 2: OGIM v2.7 Data Catalog Schema

                                 Does this data source contain any records that
HAS_COMPRESSORS boolean    no    are included in the Natural Gas Compressor         valid: 0, 1
                                 Stations layer?
                                 Does this data source contain any records that
HAS_PROCESSING   boolean   no    are included in the Gathering and Processing       valid: 0, 1
                                 layer?

                                 Does this data source contain any records that
HAS_REFINERIES   boolean   no                                                       valid: 0, 1
                                 are included in the Crude Oil Refineries layer?

                                 Does this data source contain any records that
HAS_TERMINALS    boolean   no                                                       valid: 0, 1
                                 are included in the Petroleum Terminals layer?

                                 Does this data source contain any records that
HAS_LNG          boolean   no                                                       valid: 0, 1
                                 are included in the LNG Facilities layer?

                                 Does this data source contain any records that
HAS_INJ_DISP     boolean   no                                                      valid: 0, 1
                                 are included in the Injection and Disposal layer?

                                 Does this data source contain any records that
HAS_TANKS        boolean   no                                                       valid: 0, 1
                                 are included in the Tank Battery layer?
                                 Does this data source contain any records that
HAS_EQUIP_COMP   boolean   no    are included in the Equipment and Components valid: 0, 1
                                 layer?

                                 Does this data source contain any records that
HAS_OTHER        boolean   no                                                       valid: 0, 1
                                 are included in the Stations - Other layer?

                                 Does this data source contain any records that
HAS_PIPELINES    boolean   no    are included in the Oil and Natural Gas Pipelines valid: 0, 1
                                 layer?
                                 Does this data source contain any records that
HAS_BASINS       boolean   no    are included in the Oil and Natural Gas Basins     valid: 0, 1
                                 layer?
                                 Does this data source contain any records that
HAS_FIELDS       boolean   no    are included in the Oil and Natural Gas Fields     valid: 0, 1
                                 layer?
                                 Does this data source contain any records that
HAS_BLOCKS       boolean   no    are included in the Oil and Natural Gas License    valid: 0, 1
                                 Blocks layer?
                                 Does this data source contain any records that
HAS_PRODUCTION   boolean   no    are included in the Oil and Natural Gas            valid: 0, 1
                                 Production layer?
                                 Does this data source contain any records that
HAS_FLARES       boolean   no    are included in the Natural Gas Flaring            valid: 0, 1
                                 Detections layer?




                                       Supplement page 8 of 8
