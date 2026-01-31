workspace "Gallformers" "Architecture for Gallformers V2 - Phoenix/LiveView gall identification system" {

    model {
        # People
        publicUser = person "Public User" "Browses gall database, uses identification tools"
        admin = person "Administrator" "Manages content, uploads images, edits data"

        # External Systems
        auth0 = softwareSystem "Auth0" "Authentication and authorization service" "External"
        s3Images = softwareSystem "AWS S3 (Images)" "Image storage (gallformers bucket)" "External"
        s3Backups = softwareSystem "AWS S3 (Backups)" "Database backups (gallformers-backups bucket)" "External"

        # Gallformers System
        gallformers = softwareSystem "Gallformers" "Phoenix/LiveView application providing gall identification and reference" {

            # Containers
            phoenixApp = container "Phoenix Web Application" "Handles requests, serves UI, business logic" "Elixir/Phoenix/LiveView" {

                # Core Domain Components
                speciesContext = component "Species" "Manages gall-forming species data" "Phoenix Context"
                hostsContext = component "Hosts" "Manages host plant data" "Phoenix Context"
                taxonomyContext = component "Taxonomy" "Manages taxonomic hierarchy" "Phoenix Context"

                # Content Components
                glossariesContext = component "Glossaries" "Manages glossary terms" "Phoenix Context"
                articlesContext = component "Articles" "Manages reference articles" "Phoenix Context"
                sourcesContext = component "Sources" "Manages scientific sources/citations" "Phoenix Context"

                # Feature Components
                searchContext = component "Search" "Global search across entities" "Phoenix Context"
                exploreContext = component "Explore" "Browsing and filtering" "Phoenix Context"
                idToolModule = component "ID Tool" "Identification tool logic" "Module"

                # Infrastructure Components
                imagesContext = component "Images" "Image upload, storage, metadata" "Phoenix Context"
                accountsContext = component "Accounts" "User accounts and permissions" "Phoenix Context"
                placesContext = component "Places" "Geographic data" "Phoenix Context"
                analyticsContext = component "Analytics" "Usage tracking" "Phoenix Context"

                # Component Relationships
                speciesContext -> taxonomyContext "Uses for taxonomic classification"
                speciesContext -> hostsContext "References for host associations"
                speciesContext -> imagesContext "Uses for image management"
                speciesContext -> sourcesContext "Cites scientific sources"

                hostsContext -> taxonomyContext "Uses for taxonomic classification"
                hostsContext -> imagesContext "Uses for image management"
                hostsContext -> sourcesContext "Cites scientific sources"

                searchContext -> speciesContext "Searches species"
                searchContext -> hostsContext "Searches hosts"
                searchContext -> glossariesContext "Searches glossary"

                exploreContext -> speciesContext "Browses species"
                exploreContext -> hostsContext "Browses hosts"
            }

            pubsub = container "Phoenix.PubSub" "Real-time pub/sub for LiveView updates" "GenServer"
            auditCache = container "Images.AuditCache" "Caches image audit data" "GenServer"
            sqlite = container "SQLite Database" "Stores species, hosts, galls, images, users" "SQLite" "Database"
            litestream = container "Litestream" "Continuous replication to S3" "Backup process"

            # Container Relationships
            phoenixApp -> pubsub "Publishes/subscribes" "In-process"
            phoenixApp -> auditCache "Reads/writes cache" "In-process"
            phoenixApp -> sqlite "Reads/writes data" "Ecto/SQL"
            phoenixApp -> auth0 "Validates tokens" "OAuth/HTTPS"
            phoenixApp -> s3Images "Reads/writes images" "S3 API"

            litestream -> sqlite "Replicates" "File system"
            litestream -> s3Backups "Writes backups" "S3 API"
        }

        # User Relationships
        publicUser -> gallformers "Uses" "HTTPS"
        admin -> gallformers "Manages content" "HTTPS"
        admin -> auth0 "Authenticates with"

        # Deployment
        deploymentEnvironment "Production" {
            deploymentNode "Fly.io" "iad region" "Fly.io" {
                deploymentNode "Machine" "Fly.io VM" {
                    containerInstance phoenixApp
                    containerInstance pubsub
                    containerInstance auditCache
                    containerInstance litestream
                }
                deploymentNode "Volume" "Persistent storage" {
                    containerInstance sqlite
                }
            }

            deploymentNode "AWS" "us-east-1" "AWS Cloud" {
                infrastructureNode "S3 Images Bucket" "gallformers" {
                }
                infrastructureNode "S3 Backups Bucket" "gallformers-backups" {
                }
            }
        }
    }

    views {
        # System Context (C1)
        systemContext gallformers "SystemContext" {
            include *
            autoLayout
        }

        # Container (C2)
        container gallformers "Containers" {
            include *
            autoLayout
        }

        # Component (C3)
        component phoenixApp "Components" {
            include *
            autoLayout
        }

        # Deployment
        deployment gallformers "Production" "Deployment" {
            include *
            autoLayout
        }

        # Styling
        styles {
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Person" {
                shape person
                background #08427b
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Database" {
                shape cylinder
            }
        }
    }
}
