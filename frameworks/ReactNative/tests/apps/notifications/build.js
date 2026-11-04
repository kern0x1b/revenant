const cp = require('child_process');
const fs = require('fs');
const path = require('path');

const [projectArgument, outputArgument] = process.argv.slice(2);
if (!projectArgument || !outputArgument) {
  console.error('usage: node build.js <work folder> <bundle.js>');
  process.exit(2);
}
const project = path.resolve(projectArgument);
const output = path.resolve(outputArgument);

fs.mkdirSync(project, {recursive: true});
for (const file of ['index.js', 'App.tsx', 'app.json', 'babel.config.js', 'metro.config.js', 'package.json', 'package-lock.json']) {
  fs.copyFileSync(path.join(__dirname, file), path.join(project, file));
}
if (!fs.existsSync(path.join(project, 'node_modules'))) {
  cp.execFileSync('npm', ['ci', '--no-audit', '--no-fund', '--loglevel=error'], {cwd: project, stdio: 'inherit'});
}

const nodeModules = path.join(project, 'node_modules');
const {runBuild} = require(path.join(nodeModules, 'metro'));
const {getDefaultConfig} = require(path.join(nodeModules, 'expo', 'metro-config'));

async function main() {
  const config = await getDefaultConfig(project);
  config.projectRoot = project;
  config.watchFolders = [project];
  await runBuild(config, {entry: 'index.js', platform: 'ios', dev: false, minify: false, out: output});
  console.log('notifications probe bundle ' + output);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
