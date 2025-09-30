# Nom de plume

The ultimate aim of this project is to build a system for attributing methane plumes observed by satellites to owners and operators of oil and gas wells, pipelines, compressor stations and other infrastructure.

To start with, we're just getting the relevant datasets together for analysis. My aim is to produce a .duckdb database file containing all the data we need, using a series of minimal shell scripts and the DuckDB CLI to create it, all orchestrated by a Makefile.

First task: write a parser for the Texas RRC P4 data contained in EBCDIC format in @data/, using the documentation/guide in @docs/. We need to get the data from EBCDIC into a nice set of tables in a DuckDB database, using as minimal code as possible. Try to do this in the 'proper' way, as far as possible, not translating raw characters from the EBCDIC using a lookup table or anything like that.
