#!/usr/bin/env node

const { readFileSync } = require('fs');

const template = JSON.parse(readFileSync(0, 'utf-8'));
const manifest = JSON.parse(readFileSync(process.argv[2]));
const lastBuild = manifest.builds.find(b => b.packer_run_uuid === manifest.last_run_uuid);
const artifacts = lastBuild.artifact_id.split(",");

const amiMap = {};

for (const ami of artifacts) {
	const [region, id] = ami.split(":");
	const regionEntry = template.Mappings.Regions[region] || {};
	regionEntry.ImageId = id;
	template.Mappings.Regions[region] = regionEntry;
}

console.log(JSON.stringify(template))
