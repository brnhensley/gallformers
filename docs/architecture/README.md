# Gallformers Architecture

This directory contains C4 model architecture diagrams for Gallformers V2.

## C4 Model

The [C4 model](https://c4model.com/) by Simon Brown provides a hierarchical way to visualize software architecture at different levels of detail:

1. **System Context (C1)** - Shows how the system fits in the world (external dependencies, users)
2. **Container (C2)** - Shows the high-level technical building blocks (apps, databases, services)
3. **Component (C3)** - Shows the major components within a container (Phoenix contexts)
4. **Code (C4)** - Shows implementation details (not included - too detailed)

## Diagrams

- [C1: System Context](c1-system-context.md) - Gallformers and its external dependencies
- [C2: Containers](c2-containers.md) - Runtime components on Fly.io
- [C3: Components](c3-components.md) - Phoenix contexts and their relationships

## Viewing the Diagrams

These diagrams use Mermaid syntax and will render automatically on GitHub. To view them locally:

1. Use a Markdown preview with Mermaid support (VS Code, GitHub Desktop)
2. Use the [Mermaid Live Editor](https://mermaid.live/)
3. Install a browser extension like "Markdown Viewer" with Mermaid support

## Updating

When the architecture changes significantly, update the relevant diagram(s). The diagrams are version-controlled, so you can see how the architecture evolved over time.
