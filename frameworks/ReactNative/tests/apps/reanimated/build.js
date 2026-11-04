// Builds the Reanimated probe app into one JavaScript bundle for the iOS 6 host, the way tests/bench/build.js builds
// the benchmark: the app's files are copied into a work folder, its dependencies are installed there, and Metro writes
// the bundle. Usage: node build.js <work folder> <bundle.js> [default|hermes-stable]
const cp = require('child_process');
const fs = require('fs');
const path = require('path');

const [projectArgument, outputArgument, profile = 'hermes-stable'] = process.argv.slice(2);
if (!projectArgument || !outputArgument) {
  console.error('usage: node build.js <work folder> <bundle.js> [default|hermes-stable]');
  process.exit(2);
}
const project = path.resolve(projectArgument);
const output = path.resolve(outputArgument);

fs.mkdirSync(project, {recursive: true});
for (const file of ['index.js', 'App.js', 'babel.config.js', 'package.json', 'package-lock.json']) {
  fs.copyFileSync(path.join(__dirname, file), path.join(project, file));
}
if (!fs.existsSync(path.join(project, 'node_modules'))) {
  cp.execFileSync('npm', ['install', '--no-audit', '--no-fund', '--loglevel=error'], {cwd: project, stdio: 'inherit'});
}

const nodeModules = path.join(project, 'node_modules');
const {runBuild} = require(path.join(nodeModules, 'metro'));
const {getDefaultConfig} = require(path.join(nodeModules, '@react-native', 'metro-config', 'dist', 'index.js'));

async function main() {
  const config = await getDefaultConfig(project);
  config.watchFolders = [project];
  await runBuild(config, {
    entry: 'index.js',
    platform: 'ios',
    dev: false,
    minify: false,
    out: output,
    unstable_transformProfile: profile,
  });
  console.log('reanimated probe bundle ' + output + ' profile ' + profile);
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
