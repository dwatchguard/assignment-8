ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias Wrangler
        provides default_threshold
        shares sensors, sensor_temperatures
    }
    global {
        default_threshold = 70;
        default_location = "Basement";
        default_SMS = 4433709548;
        sensors = function() {
            ent:sensors;
        };
        sensor_temperatures = function() {
            ent:sensors.values().map(function(x) {
                Wrangler:skyQuery(x,"temperature_store","temperatures", {});
            })
        };
    }
    rule intialize_sensors {
        select when wrangler ruleset_added where event:attr("rids") >< meta:rid
        if ent:sensors.isnull() then noop();
        fired {
            ent:sensors := {};
        }
    }
	rule intialize_channels {
        select when wrangler ruleset_added where event:attr("rids") >< meta:rid
        if ent:cids.isnull() then noop();
        fired {
            ent:cids := {};
        }
    }
    rule create_sensor {
        select when sensor new_sensor
        pre {
            name = event:attr("name");
            contains = ent:sensors >< name;
        }
        if contains == false && name != null then 
             send_directive("update", {"Creating Child": "Creating Child Pico: "+ name})
        fired {
            raise wrangler event "child_creation" 
                attributes { "name" : name, "rids" : "temperature_store;wovyn_base;sensor_profile"};
        }
    }
    rule store_child_data {
        select when wrangler child_initialized
        pre {
        name = event:attr("name");
        eci = event:attr("eci");
        val = ent:sensors.put(name, eci);
        }
        event:send({"eci": eci, "domain":"sensor", "type":"profile_updated", "attrs":{"name": name, "location" : default_location, "threshold" : default_threshold, "SMS" : default_SMS}})
        fired {
           ent:sensors := val;
		}
    }
    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            name = event:attr("name");
            contains = sensors() >< name;
            val = ent:sensors.delete(name);
        }
        if name != null && contains then 
            send_directive("update", {"Deleting Child": "Deleting Child Pico: "+ name})
        fired {
            raise wrangler event "child_deletion"
                attributes { "name" : name };
            ent:sensors := val;
        } 
    }
	rule request_temperature {
			select when sensor recent_temperatures
			pre {
				map = wrangler.createChannel(random:uuid(), "temperature_collection");
				cid = map.id;
				val = ent:cids.put("cid" : ent:sensors);
				}
			fired {
				raise sensor event "get_recent_temperatures"
					attributes {"cid" : cid};
				ent:cids := val;
            }
	}
	rule requested_temperatures {
		select when sensor get_recent_temperatures where event:attr("cid") != null
			foreach ent:sensors setting (name, eci)
				event:send({"eci" : eci, "eid" : event:attr("cid"), "domain" : "sensor", "type" : "send_temperatures"})
	}
	rule gather_temperatures {
		select when sensor recent_temperatures
		
		
	}
    
}
