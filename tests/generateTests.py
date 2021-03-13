import glob,os
import yaml
import json


files = glob.glob("yaml/*.yml")
if (not os.path.exists("json")):
    print("Creating json output directory")
    os.mkdir("json")

for f in files:
    print("Generating json for {}".format(f))
    o = os.path.join("expected",os.path.splitext(os.path.split(f)[-1])[0]+".json")
    print("Saving to {}".format(o))
    try:
        with open(f, 'r') as yml_file, open(o, 'w') as json_file:
            yml = yaml.safe_load(yml_file)
            json.dump(yml, json_file, default=lambda x: list(x) if isinstance(x, set) else x)
    except:
        print("Failed to create output for {}".format(f))

print("All Done!")

