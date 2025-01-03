@with_kw struct esm_zones
    samples::DataFrame
    groups
    transformations
    views
end

struct group

end

function transformation(eq_list)
    for i in eq_list
        x = Meta.parse(i)
        
    end
end

function read_esm(filen)
    ef = JSON.parsefile(filen)
    es = esm_zones(
        samples=DataFrame([(i, j, ef["samples"][i]["type"],ef["samples"][i]["values"][j]) for i in keys(ef["samples"]) for j in keys(ef["samples"][i]["values"])],["name","channel","type","values"]),#DataFrame(ef["samples"]),
        groups=DataFrame([(i,ef["groups"][i]["sample_IDs"],ef["groups"][i]["metadata"],:(filter(row -> row.name in ef["groups"][i]["sample_IDs"], samples, view=true))) for i in keys(ef["groups"])],["group","sample_IDs","metadata","meta_select"]),
        transformations=ef["transformations"],
        views=ef["views"]
    )
    print(es.groups)
end

read_esm("./ESM_proto.json")