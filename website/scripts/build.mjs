import { cp, mkdir, rm, copyFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const websiteDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const repositoryDirectory = resolve(websiteDirectory, '..');
const sourceDirectory = resolve(websiteDirectory, 'src');
const outputDirectory = resolve(websiteDirectory, 'dist');
const assetDirectory = resolve(outputDirectory, 'assets');

await rm(outputDirectory, { recursive: true, force: true });
await cp(sourceDirectory, outputDirectory, { recursive: true });
await mkdir(assetDirectory, { recursive: true });

await Promise.all([
  copyFile(
    resolve(repositoryDirectory, 'assets/brand/Pushlog-logo-svg.svg'),
    resolve(assetDirectory, 'pushlog-mark.svg'),
  ),
  copyFile(
    resolve(repositoryDirectory, 'assets/brand/pushlog_icon_master.png'),
    resolve(assetDirectory, 'pushlog-icon.png'),
  ),
  copyFile(
    resolve(repositoryDirectory, 'store/ios/screenshots/raw/01-today.png'),
    resolve(assetDirectory, 'pushlog-today.png'),
  ),
]);

console.log(`Built Pushlog site at ${outputDirectory}`);
