To investigate the true extent of methane emissions from the US LNG supply chain, we adapted a methodology we had previously used to [expose deforestation](https://www.bbc.co.uk/programmes/p090f6h6) linked to cattle farms supplying big Brazilian meat companies.

We extracted the locations and operator information for hundreds of thousands of oil and gas wells from [data files](https://www.bbc.co.uk/programmes/p090f6h6) held by the Texas Railroad Commission (RRC) in a mainframe format originally designed for magnetic tape. While previous LLM coding models had failed at this task, Claude Sonnet 4.5 produced robust parsers for multiple complex datasets in a couple of hours.

We then cross-referenced the data with the latest methane emissions observations from the Carbon Mapper project's Tanager-1 satellite, matching plumes to wells using a confidence score based on:

- the well's distance from the plume's centre, as assessed by Carbon Mapper;
- the number of other wells nearby; and
- the number operated by the same operator as the matched well.

To test the attribution methodology, we generated a set of composite images covering a 1km2 bounding box around each matched plume, including representations of the plume centre, the plume itself and the well. We then passed these images to a multi-modal LLM [model TBC] with a detailed prompt based on our own experience manually reviewing and attributing plumes to wells.
