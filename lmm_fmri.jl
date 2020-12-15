using CSV
using DataFrames
using MixedModels

dat = DataFrame(CSV.File("slice.csv"; missingstrings=["NA","","NaN"]))
select!(dat, Not(:Column1))
dat = stack(dat, Not([:subjectID, :sex, :age, :ethnicity, :YoE, :YoE_labels, :inc_par, :income_labels, :scanner, :timepoint]);
      variable_name=:roi,
      value_name=:connectivity)

# ROI has so many levels -- this really should be a random effect
# and already is, so we cut it from the FE, see also https://www.muscardinus.be/2017/08/fixed-and-random/
# this slice only has a single timepoint, so we also drop the timepoint predictor
form = @formula(connectivity ~ 1 + (1| subjectID) + (1| subjectID&roi))

contr = Dict(:roi => Grouping(),
             :subjectID => Grouping())

# let's see if we can even construct a big model
mod = LinearMixedModel(form, dat; contrasts=contr)

# seems to work, let's fit
@time fit!(mod)

