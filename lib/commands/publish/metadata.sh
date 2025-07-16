#!/bin/bash
# lib/commands/publish/metadata.sh - Gestion métadonnées et formats

# === MÉTADONNÉES AVEC GESTION HTML ===
create_merged_metadata() {
    local format="$1"
    local output_file="$2"
    local project_name="$3"
    local include_toc="${4:-true}"
    local embeddable="${5:-false}"

    # === DEBUG VARIABLES ===
    log_debug "🔍 Variables disponibles dans create_merged_metadata:"
    log_debug "   TITLE='${TITLE:-NON_DEFINI}'"
    log_debug "   AUTHOR_NAME='${AUTHOR_NAME:-NON_DEFINI}'"
    log_debug "   project_name='$project_name'"


    # Détecter le type de sortie
    local output_type=$(detect_output_format "$format")

    # Détecter l'image de couverture
    local cover_image=""
    local cover_candidates=(
        "cover.jpg" "cover.png" "cover.jpeg"
        "couverture.jpg" "couverture.png"
        "Cover.jpg" "Cover.png"
        "assets/cover.jpg" "assets/cover.png"
        "images/cover.jpg" "images/cover.png"
    )

    for candidate in "${cover_candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            cover_image="$candidate"
            log_debug "🎨 Couverture trouvée: $cover_image"
            break
        fi
    done

    if [[ -z "$cover_image" ]]; then
        log_debug "📷 Aucune couverture trouvée (cherché: ${cover_candidates[*]})"
    fi

    log_debug "Création métadonnées: format=$format, type=$output_type, toc=$include_toc, embeddable=$embeddable"

    {
        echo "---"

        # Base metadata avec substitutions
        if [[ -f "formats/base.yaml" ]]; then
            local header_includes_section=false
            while IFS= read -r line; do
                # Substitutions des variables
                line=$(echo "$line" | sed "s/{{TITLE}}/$TITLE/g")
                line=$(echo "$line" | sed "s/{{AUTHOR}}/${AUTHOR_NAME:-Auteur}/g")
                line=$(echo "$line" | sed "s/{{DATE}}/$(date '+%Y-%m-%d')/g")
                line=$(echo "$line" | sed "s|{{COVER_IMAGE}}|$cover_image|g")

                # Exclure header-includes pour éviter conflit
                if [[ "$line" =~ ^header-includes: ]]; then
                    # On a trouvé header-includes, ignorer jusqu'à la prochaine section
                    header_includes_section=true
                    continue
                elif [[ "$header_includes_section" == "true" ]]; then
                    # Dans la section header-includes
                    if [[ "$line" =~ ^[[:space:]]+.* ]]; then
                        # Ligne indentée = contenu header-includes, ignorer
                        continue
                    else
                        # Ligne non-indentée = fin de la section header-includes
                        header_includes_section=false
                        echo "$line"
                    fi
                else
                    # Ligne normale, garder
                    echo "$line"
                fi
            done < "formats/base.yaml"
        else
            # Fallback sans base.yaml
            echo "title: \"$TITLE\""
            echo "author: \"${AUTHOR_NAME:-Auteur}\""
            echo "date: \"$(date '+%Y-%m-%d')\""
            echo "lang: fr-FR"
            if [[ -n "$cover_image" ]]; then
                echo "epub-cover-image: \"$cover_image\""
            fi
        fi

        echo ""

        # Format specific avec substitutions et gestion HTML
        if [[ -f "formats/$format.yaml" ]]; then
            while IFS= read -r line; do
                # Substitutions template standard
                line=$(echo "$line" | sed "s/{{TITLE}}/$TITLE/g")
                line=$(echo "$line" | sed "s/{{AUTHOR}}/${AUTHOR_NAME:-Auteur}/g")
                line=$(echo "$line" | sed "s/{{DATE}}/$(date '+%Y-%m-%d')/g")
                line=$(echo "$line" | sed "s|{{COVER_IMAGE}}|$cover_image|g")

                # Omettre epub-cover-image si pas d'image trouvée
                if [[ "$line" =~ ^epub-cover-image: ]] && [[ -z "$cover_image" ]]; then
                    continue
                fi

                # === GESTION SPÉCIFIQUE HTML ===
                if [[ "$output_type" == "html" ]]; then
                    # Gérer table-of-contents dynamiquement
                    if [[ "$line" =~ ^table-of-contents: ]]; then
                        echo "table-of-contents: $include_toc"
                        continue
                    fi

                    # Gérer standalone pour embeddable
                    if [[ "$line" =~ ^standalone: ]] && [[ "$embeddable" == "true" ]]; then
                        echo "standalone: false"
                        continue
                    fi

                    # Gérer self-contained pour embeddable
                    if [[ "$line" =~ ^self-contained: ]] && [[ "$embeddable" == "true" ]]; then
                        echo "self-contained: false"
                        continue
                    fi
                fi

                # Ligne normale
                echo "$line"
            done < "formats/$format.yaml"
        fi

        echo "---"
    } > "$output_file"

    log_debug "✅ Métadonnées créées: $output_file"
}

# === GÉNÉRATION NOMS FICHIERS ===
generate_output_filename() {
    local format="$1"
    local max_chapters="$2"
    local output_name="$3"
    local extension="$4"
    local project_name="$5"
    local timestamp="$6"

    if [[ -n "$output_name" ]]; then
        echo "${output_name}.${extension}"
        return 0
    fi

    if [[ "$max_chapters" != "99" ]]; then
        # Utiliser la même logique que context pour le nommage
        local chapter_suffix=""
        if [[ "$max_chapters" == *","* ]]; then
            # Liste de chapitres : Ch1,5,10
            chapter_suffix="Ch$(echo "$max_chapters" | tr ',' '-')"
        elif [[ "$max_chapters" == *"-"* ]]; then
            # Range : Ch1-10
            chapter_suffix="Ch${max_chapters}"
        else
            # Chapitre unique : Ch5
            chapter_suffix="Ch${max_chapters}"
        fi
        echo "${project_name}-${format}-${chapter_suffix}-${timestamp}.${extension}"
    else
        echo "${project_name}-${format}-${timestamp}.${extension}"
    fi
}

# === DÉTECTION EXTENSION ===
get_output_extension() {
    local output_type="$1"

    case "$output_type" in
        "epub") echo "epub" ;;
        "html") echo "html" ;;
        *) echo "pdf" ;;
    esac
}

# === EXPORTS ===
export -f create_merged_metadata
export -f generate_output_filename
export -f get_output_extension

# Marquer module comme chargé
readonly SILK_PUBLISH_METADATA_LOADED=true
