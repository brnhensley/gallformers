import { readFileSync, readdirSync, statSync } from 'fs';
import { join, relative } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = join(__filename, '..');

const EXTENSIONS = ['.ts', '.tsx'];
const IMPORT_REGEX = /import\s+(?:{[^}]*}|\*\s+as\s+\w+|\w+)\s+from\s+['"]([^'"]+)['"]/g;

function findFiles(dir, fileList = []) {
    const files = readdirSync(dir);
    
    files.forEach(file => {
        const filePath = join(dir, file);
        const stat = statSync(filePath);
        
        if (stat.isDirectory() && !filePath.includes('node_modules') && !filePath.includes('.git')) {
            findFiles(filePath, fileList);
        } else if (EXTENSIONS.includes(file.slice(-3)) || EXTENSIONS.includes(file.slice(-4))) {
            fileList.push(filePath);
        }
    });
    
    return fileList;
}

function checkImports(filePath) {
    const content = readFileSync(filePath, 'utf8');
    const imports = [...content.matchAll(IMPORT_REGEX)].map(match => match[1]);
    const errors = [];

    imports.forEach(importPath => {
        if (importPath.startsWith('.')) {
            const absolutePath = join(filePath, '..', importPath);
            try {
                // Try to resolve the import path
                require.resolve(absolutePath);
            } catch (error) {
                // If the import fails, check if it's a case sensitivity issue
                const dir = join(filePath, '..');
                const files = readdirSync(dir);
                const matchingFile = files.find(f => 
                    f.toLowerCase() === importPath.split('/').pop().toLowerCase()
                );

                if (matchingFile && matchingFile !== importPath.split('/').pop()) {
                    errors.push({
                        file: relative(process.cwd(), filePath),
                        import: importPath,
                        suggested: importPath.replace(importPath.split('/').pop(), matchingFile)
                    });
                }
            }
        }
    });

    return errors;
}

function main() {
    const rootDir = join(__dirname, '..');
    const files = findFiles(rootDir);
    let hasErrors = false;

    console.log(`Scanning ${files.length} TypeScript/TSX files for case sensitivity issues...`);

    files.forEach(file => {
        const errors = checkImports(file);
        if (errors.length > 0) {
            hasErrors = true;
            console.error(`\nCase sensitivity issues found in ${file}:`);
            errors.forEach(error => {
                console.error(`  Import: ${error.import}`);
                console.error(`  Suggested: ${error.suggested}`);
            });
        }
    });

    if (!hasErrors) {
        console.log('No case sensitivity issues found!');
    } else {
        console.error('\nPlease fix the case sensitivity issues above before committing.');
        process.exit(1);
    }
}

main(); 