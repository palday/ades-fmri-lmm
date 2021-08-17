using CSV
using CategoricalArrays
using DataFrames
using MixedModels
using StandardizedPredictors
using StatsModels
using Tables

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

numeric = Dict(:timepoint => Center(2),
               :region => Grouping(),
               :subjectID => Grouping())
categoric = Dict(:timepoint => HelmertCoding(),
                 :region => Grouping(),
                 :subjectID => Grouping())

form = @formula(conn ~ 1 + timepoint + (1+timepoint|subjectID) + (1+timepoint|region))

# let's see if we can even construct a big model
@time mod_numeric = LinearMixedModel(form, dat; contrasts=numeric)
# seems to work, let's fit
@time let fname = "mod_numeric.json"
    if isfile(fname)
        restoreoptsum!(mod_numeric, fname)
    else
        # about 1s/iter on my computer, 600-700 iterations necessary
        fit!(mod_numeric)
        saveoptsum(fname, mod_numeric)
    end
    mod_numeric
end

# let's see if we can even construct a big model
@time mod_categoric = LinearMixedModel(form, dat; contrasts=categoric)

# sparsity doesn't help here
# tbl, _ = StatsModels.missing_omit(Tables.columntable(dat), form)
# sch = schema(form, tbl, categoric)
# form = apply_schema(form, sch, LinearMixedModel)
# y, Xs = modelcols(form, tbl)
# fe = first(Xs)
# Base.summarysize(fe)
# Base.summarysize(sparse(fe))
# mod_categoric = LinearMixedModel(y, Xs, form)

@time let fname = "mod_categoric.json"
    if isfile(fname)
        restoreoptsum!(mod_categoric, fname)
    else
        # about 10s/iter on my computer, 5200-5300 iterations necessary
        fit!(mod_categoric)
        saveoptsum(fname, mod_categoric)
    end

    mod_categoric
end

form_interaction = @formula(conn ~ 1 + timepoint + (1+timepoint|subjectID) + (1+timepoint|region & subjectID))

# let's see if we can even construct a big model
@time mod_numeric_interaction = LinearMixedModel(form_interaction, dat; contrasts=numeric)
# seems to work, let's fit
@time let fname = "mod_numeric_interaction.json"
    if isfile(fname)
        restoreoptsum!(mod_numeric_interaction, fname)
    else
        # about 15s/iter on my computer, did not let run for more than a few dozen iterations
        fit!(mod_numeric_interaction)
        saveoptsum(fname, mod_numeric_interaction)
    end
    mod_numeric_interaction
end

@time mod_categoric_interaction = LinearMixedModel(form_interaction, dat; contrasts=categoric)
@time let fname = "mod_categoric_interaction.json"
    if isfile(fname)
        restoreoptsum!(mod_categoric_interaction, fname)
    else
        # did not even try this
        fit!(mod_categoric_interaction)
        saveoptsum(fname, mod_categoric_interaction)
    end

    mod_categoric_interaction
end
