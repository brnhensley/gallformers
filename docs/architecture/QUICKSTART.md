# Architecture Diagrams Quick Start

## View Diagrams Interactively

The easiest way to view the architecture diagrams:

```bash
cd docs/architecture
./view.sh
```

This starts Structurizr Lite at http://localhost:8080. You'll see:

- **System Context** - High-level view of Gallformers and external systems
- **Containers** - Runtime components (Phoenix app, database, GenServers)
- **Components** - Phoenix contexts and their relationships
- **Deployment** - Production infrastructure on Fly.io

Press Ctrl+C to stop when done.

## Export Diagrams as Images

To generate PNG or SVG files for documentation:

```bash
# Install CLI (one time)
brew install structurizr-cli

# Export to PNG
cd docs/architecture
structurizr-cli export -workspace workspace.dsl -format png

# Or SVG for better quality
structurizr-cli export -workspace workspace.dsl -format svg
```

This creates `SystemContext.png`, `Containers.png`, `Components.png`, and `Deployment.png` in the current directory.

## Edit the Architecture

The architecture is defined in `workspace.dsl`. To make changes:

1. Edit `workspace.dsl`
2. Run `./view.sh` to see changes live
3. Commit the updated DSL file

The DSL is the source of truth - diagrams are generated from it.

## Structurizr DSL Basics

```groovy
# Define elements
person "Name" "Description"
softwareSystem "Name" "Description"
container "Name" "Description" "Technology"
component "Name" "Description" "Type"

# Define relationships
elementA -> elementB "Label" "Technology"

# Create views
systemContext <system> {
    include *
    autoLayout
}
```

See [Structurizr DSL docs](https://github.com/structurizr/dsl/tree/master/docs) for full syntax.

## Troubleshooting

**Docker not installed?**
```bash
brew install docker
# Or use Structurizr CLI to export static images instead
```

**Port 8080 already in use?**
```bash
# Change port in view.sh
docker run -it --rm -p 9090:8080 ...
# Then open http://localhost:9090
```

**Want to customize styling?**
Edit the `styles` section in `workspace.dsl`.
