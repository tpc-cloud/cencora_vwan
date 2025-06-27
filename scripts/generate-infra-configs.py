import os
import sys
import yaml

def save_yaml(data, folder, key_name):
    os.makedirs(folder, exist_ok=True)
    for item in data:
        name = item[key_name]
        path = os.path.join(folder, f"{name}.yaml")
        with open(path, "w") as f:
            yaml.dump(item, f, sort_keys=False)
        print(f"Wrote: {path}")

def expand_vnets(base, envs, subscription, location):
    result = []
    for env in envs:
        cidr = base.get("overrides", {}).get(env, {}).get("cidr", base["cidr"])
        result.append({
            "name": f"{base['name']}-{env}",
            "address_space": cidr,
            "location": location,
            "resource_group": f"rg-{subscription}-{env}",
            "environment": env
        })
    return result

def expand_hubs(base, envs, subscription, location):
    result = []
    for env in envs:
        hub = {
            "name": f"{base['name']}-{env}",
            "address_prefix": base["cidr"],
            "sku": base.get("sku", "Standard"),
            "hub_routing_preference": base.get("hub_routing_preference", "ASPath"),
            "vpn_gateway": {
                "name": f"vpngw-{base['name']}-{env}",
                "scale_unit": base.get("vpn_gateway", {}).get("scale_unit", 1)
            },
            "location": location,
            "environment": env
        }
        result.append(hub)
    return result

def main(path):
    with open(path, "r") as f:
        config = yaml.safe_load(f)

    subscription = config["subscription_name"]
    location = config["location"]
    environments = config["environments"]

    all_vnets = []
    for vnet in config.get("vnets", []):
        all_vnets.extend(expand_vnets(vnet, environments, subscription, location))

    all_hubs = []
    for hub in config.get("hubs", []):
        all_hubs.extend(expand_hubs(hub, environments, subscription, location))

    save_yaml(all_vnets, "terraform/config/vnets", "name")
    save_yaml(all_hubs, "terraform/config/hubs", "name")

if __name__ == "__main__":
    main(sys.argv[1])
