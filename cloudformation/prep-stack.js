#!/usr/bin/env node
const { readFileSync } = require('fs');

const mode = process.argv[2] || "pro";

const template = JSON.parse(readFileSync(0, 'utf-8'));
const manifest = JSON.parse(readFileSync(process.argv[3]));
const lastBuild = manifest.builds.find(b => b.packer_run_uuid === manifest.last_run_uuid);
const artifacts = lastBuild.artifact_id.split(",");

const amiMap = {};

for (const ami of artifacts) {
	const [region, id] = ami.split(":");
	const regionEntry = template.Mappings.Regions[region] || {};
	regionEntry.ImageId = id;
	template.Mappings.Regions[region] = regionEntry;
}

const useMinimalDefaults = () => {
	template.Parameters.AppInstanceType.Default = "t3.micro"
	template.Parameters.StreamInstanceType.Default = "t3.micro"
	template.Parameters.AutoPauseDb.Default = "Yes - Pause database when not in use"
	template.Parameters.LoadBalancingMethod.Default = "DNS Round Robin"
	template.Parameters.MaxStorage.Default = 128
};

if (mode === "personal") {
	// Strip instance count setting, always run a single server unless user overrides.
	const metadata = template.Metadata['AWS::CloudFormation::Interface'];
	// Remove instance count from parameter groups + parameters
	for (pg of metadata.ParameterGroups) {
		pg.Parameters = pg.Parameters.filter(p => !p.endsWith("InstanceCount"));
	}

	for (p of Object.keys(metadata.ParameterLabels)) {
		if (p.endsWith("InstanceCount")) {
			delete metadata.ParameterLabels[p];
		}
	}

	for (p of Object.keys(template.Parameters)) {
		if (p.endsWith("InstanceCount")) {
			delete template.Parameters[p];
		}
	}

	const walk = (o, k, parent) => {
		if (o instanceof Array) {
			for (let i in o) {
				walk(o[i], i, o);
			}
		} else if (o instanceof Object) {
			// Replace Refs to InstanceCount to 1
			if (o.Ref && typeof(o.Ref) === "string" && o.Ref.endsWith("InstanceCount")) {
				parent[k] = 1;
			}

			for (let k of Object.keys(o)) {
				walk(o[k], k, o);
			}
		}
	}

	walk(template.Resources);
	walk(template.Conditions);

	useMinimalDefaults();
} else if (mode === "beta") {
	useMinimalDefaults();
} else if (mode === "pro") {
	template.Parameters.AppInstanceCount.Default = 2
	template.Parameters.StreamInstanceCount.Default = 2
}

console.log(JSON.stringify(template))
