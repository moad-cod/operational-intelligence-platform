Staging: Preparing our atomic building blocks

    The staging layer is where we bring all the individual components we're going to use to build our more complex and useful models into the project.

    File names ==> stg_[source]__[entity]s.sql


the most standard types of staging model transformations are:
    ✅ Renaming
    ✅ Type casting
    ✅ Basic computations (e.g. cents to dollars)
    ✅ Categorizing (using conditional logic to group values into buckets or booleans, such as in the case when statements above)
    ✅ Unioning disparate but symmetrical sources
    ✅ Materialized as views
        -Any downstream model referencing our staging models will always get the freshest data possible from all of the component views it’s pulling together and materializing.
        -It avoids wasting space in the warehouse on models that are not intended to be queried by data consumers, and thus do not need to perform as quickly or efficiently.