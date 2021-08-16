using CSV
using CategoricalArrays
using DataFrames
using MixedModels
using StandardizedPredictors

using MKL

# R-code provided by JA
# library(tidyverse)
# tot.add <- read_csv("tot.add.csv")

# tot <- tot.add %>%
#   select(-1) %>%
#   gather(region, conn, -(subjectID:scanner), -(timepoint)) %>%
#   mutate(timepoint.nu = as.numeric(timepoint),
#          timepoint = as.character(timepoint),
#          timepoint.nu = scale(timepoint.nu, center = TRUE, scale = FALSE))

dat = DataFrame(CSV.File("tot.add.csv"; missingstrings=["NA","","NaN"]))
select!(dat, Not([:Column1, :X1]))
dat = stack(dat,
            Not([:subjectID, :sex, :age, :ethnicity, :YoE, :YoE_labels, :inc_par, :income_labels, :scanner, :timepoint]);
            variable_name=:region, value_name=:conn)
transform!(dat, :subjectID => compress ∘ categorical,
                :sex => compress ∘ categorical,
                :ethnicity => compress ∘ categorical,
                :YoE_labels => compress ∘ categorical,
                :income_labels => compress ∘ categorical,
                :region => compress ∘ categorical;
           renamecols=false)

form = @formula(conn ~ 1 + timepoint + (1+timepoint|subjectID) + (1+timepoint|region))

numeric = Dict(:timepoint => Center(2),
               :region => Grouping(),
               :subjectID => Grouping())

# let's see if we can even construct a big model
@time mod_numeric = LinearMixedModel(form, dat; contrasts=numeric)
GC.gc(true)
# seems to work, let's fit
@time fit!(mod_numeric)


categoric = Dict(:timepoint => HelmertCoding(),
                 :region => Grouping(),
                 :subjectID => Grouping())

# let's see if we can even construct a big model
@time mod_categoric = LinearMixedModel(form, dat; contrasts=categoric)

# seems to work, let's fit
@time fit!(mod_categoric)
