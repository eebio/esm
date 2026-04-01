abstract type AbstractFluorescenceMethod <: AbstractPlateReaderMethod end

"""
    fluorescence(data_fl, time_fl, data_od, time_od, method::AbstractFluorescenceMethod)

Calculate fluorescence per cell (normalised by OD).

# Arguments
- `data_fl`: a DataFrame of fluorescence measurements.
- `time_fl`: a DataFrame of times for the fluorescence measurements.
- `data_od`: a DataFrame of OD measurements.
- `time_od`: a DataFrame of times for the OD measurements.
- `method`: the method to use for calculating fluorescence per cell.
"""
function fluorescence end

@kwdef struct RatioAtTime <: AbstractFluorescenceMethod
    time::Float64
end

function fluorescence(data_fl, time_fl, data_od, time_od, method::RatioAtTime)
    time = method.time
    fluorescence_at_time = at_time(data_fl, time_fl, time)
    od_at_time = at_time(data_od, time_od, time)
    out = DataFrame()
    for col in names(od_at_time)
        if isnan(time) || ! (fluorescence_at_time isa DataFrameRow) || ! (od_at_time isa DataFrameRow)
            @warn "Invalid time of $time specified for fluorescence per cell. Returning NaN for column $col."
            out[!, col] = [NaN]
            continue
        end
        out[!, col] = [fluorescence_at_time[col] / od_at_time[col]]
    end
    return out
end

@kwdef struct RatioAtMaxGrowth <: AbstractFluorescenceMethod
    method::AbstractGrowthRateMethod
end

function fluorescence(data_fl, time_fl, data_od, time_od, method::RatioAtMaxGrowth)
    time = time_to_max_growth(data_od, time_od, method.method)
    out = DataFrame()
    for col in names(data_od)
        out[!, col] = ESM.fluorescence(data_fl, time_fl, data_od, time_od, RatioAtTime(time[1, col]))[:, col]
    end
    return out
end
