#!/bin/bash

# GitHub Migration Script
# Author: TranKhanh
# Features:
#   - Transfer repositories between accounts/orgs
#   - Export/Import starred repositories
#   - Export/Import following
#   - Export followers (backup only)
#   - Export/Import gists
#   - Dry-run mode
#   - Logging




# ====== CONFIG ======
OLD_USER=""
NEW_OWNER=""
DRY_RUN="false"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # reset color

# Data folder relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/Data_Files"
mkdir -p "$DATA_DIR"


# ====== CHECL LOGIN ======

# check_login() {
#     echo "Checking GitHub CLI login status..."
#     STATUS=$(gh auth status 2>&1)
#     if echo "$STATUS" | grep -q "Logged in to github.com"; then
#         LOGIN_USER=$(gh auth status --show-token | grep "Logged in to github.com as" | awk '{print $6}')
#         echo -e "Logged in as: ${GREEN}$LOGIN_USER${NC}"
#     else
#         echo -e "${RED}Not logged in or token invalid.${NC}"
#         echo "Please run 'gh auth login' or refresh token before continuing."
#         return 1
#     fi

#     echo "==========="
# }

check_login() {
    echo -e "${BLUE}Checking GitHub CLI login status...${NC}"
    if LOGIN_USER=$(gh auth status 2>/dev/null | grep "Logged in to github.com as" | awk '{print $6}'); then
        echo -e "Logged in as: ${GREEN}$LOGIN_USER${NC}"
        return 0
    else
        echo -e "${RED}Not logged in or token invalid.${NC}"
        echo -e "${YELLOW}Please run 'gh auth login' or refresh your token before continuing.${NC}"
        return 1
    fi
    echo "==========="
}



# ====== FUNCTIONS ======

transfer_repos() {
     check_login || return
    if [ -z "$OLD_USER" ] || [ -z "$NEW_OWNER" ]; then
        echo -e "${RED}You must set OLD_USER and NEW_OWNER first.${NC}"
        return
    fi

    echo -e "${CYAN}Fetching repos from $OLD_USER...${NC}"
    repos=$(gh repo list $OLD_USER --limit 200 --json name -q '.[].name')

    for repo in $repos; do
        echo -e "${YELLOW}Transferring repo: $repo ...${NC}"
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${GREEN}[Dry Run] Would transfer $repo to $NEW_OWNER${NC}"
        else
            gh api \
                -X POST \
                -H "Accept: application/vnd.github+json" \
                repos/$OLD_USER/$repo/transfer \
                -f new_owner=$NEW_OWNER
            echo -e "${GREEN}Done: $repo${NC}"
        fi
    done
}

export_stars() {
    check_login || return
    FILE="$DATA_DIR/starred_repos.txt"
    echo -e "${CYAN}Exporting starred repos to $FILE...${NC}"
    gh api -X GET users/$OLD_USER/starred --paginate -q '.[].full_name' > "$FILE"
}

import_stars() {
    check_login || return
    FILE="$DATA_DIR/starred_repos.txt"
    echo -e "${CYAN}Importing stars from $FILE...${NC}"
    while read repo; do
        [ -n "$repo" ] || continue
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${GREEN}[Dry Run] Would star $repo${NC}"
        else
            gh api -X PUT -H "Accept: application/vnd.github+json" user/starred/$repo
            echo -e "${GREEN}Starred: $repo${NC}"
        fi
    done < "$FILE"
}

export_following() {
    check_login || return
    FILE="$DATA_DIR/following_list.txt"
    echo -e "${CYAN}Exporting following to $FILE...${NC}"
    gh api -X GET users/$OLD_USER/following --paginate -q '.[].login' > "$FILE"
}

import_following() {
    check_login || return
    FILE="$DATA_DIR/following_list.txt"
    echo -e "${CYAN}Importing following from $FILE...${NC}"
    while read user; do
        [ -n "$user" ] || continue
        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${GREEN}[Dry Run] Would follow $user${NC}"
        else
            gh api -X PUT user/following/$user
            echo -e "${GREEN}Followed: $user${NC}"
        fi
    done < "$FILE"
}

export_followers() {
    check_login || return
    FILE="$DATA_DIR/followers_list.txt"
    echo -e "${CYAN}Exporting followers to $FILE...${NC}"
    gh api -X GET users/$OLD_USER/followers --paginate -q '.[].login' > "$FILE"
}

export_gists() {
    check_login || return
    FILE="$DATA_DIR/gists_list.json"
    echo -e "${CYAN}Exporting gists to $FILE...${NC}"
    gh api -X GET users/$OLD_USER/gists --paginate > "$FILE"
}

import_gists() {
    check_login || return
    FILE="$DATA_DIR/gists_list.json"
    echo -e "${CYAN}Importing gists from $FILE...${NC}"
    echo -e "${YELLOW}(Not fully implemented - manual gist creation may be required)${NC}"
}

toggle_dryrun() {
    if [ "$DRY_RUN" = "true" ]; then
        DRY_RUN="false"
    else
        DRY_RUN="true"
    fi
    echo -e "${YELLOW}Dry-run mode set to: $DRY_RUN${NC}"
}

set_olduser() {
    read -p "Enter OLD_USER (source account): " OLD_USER
    echo -e "${GREEN}OLD_USER set to: $OLD_USER${NC}"
}

set_newowner() {
    read -p "Enter NEW_OWNER (target account): " NEW_OWNER
    echo -e "${GREEN}NEW_OWNER set to: $NEW_OWNER${NC}"
}

# ====== MENU ======
while true; do
    echo ""
    echo -e "${YELLOW}==========================================${NC}"
    echo -e "${CYAN}     GitHub Migration Tool  ($(date))${NC}"
    echo -e "${YELLOW}==========================================${NC}"
    echo -e ""
    echo -e "  ${GREEN} 1)${NC}  Transfer repositories"
    echo -e "  ${GREEN} 2)${NC}  Export starred repos"
    echo -e "  ${GREEN} 3)${NC}  Import starred repos"
    echo -e "  ${GREEN} 4)${NC}  Export following"
    echo -e "  ${GREEN} 5)${NC}  Import following"
    echo -e "  ${GREEN} 6)${NC}  Export followers"
    echo -e "  ${GREEN} 7)${NC}  Export gists"
    echo -e "  ${GREEN} 8)${NC}  Import gists"
    
    if [ "$DRY_RUN" = "ON" ]; then
        STATUS_COLOR=$GREEN
    else
        STATUS_COLOR=$RED
    fi
    echo -e "  ${GREEN} 9)${NC}  Toggle dry-run mode (currently: ${STATUS_COLOR}$DRY_RUN${NC})"

    echo -e "  ${GREEN}10)${NC}  Set OLD_USER (current: $OLD_USER)"
    echo -e "  ${GREEN}11)${NC}  Set NEW_OWNER (current: $NEW_OWNER)"
    echo ""
    echo -e "  ${RED} 0)${NC}  Exit"
    echo -e "${YELLOW}------------------------------------------${NC}"
    read -p "Choose: " CHOICE
    clear

    case $CHOICE in
        1) transfer_repos ;;
        2) export_stars ;;
        3) import_stars ;;
        4) export_following ;;
        5) import_following ;;
        6) export_followers ;;
        7) export_gists ;;
        8) import_gists ;;
        9) toggle_dryrun ;;
        10) set_olduser ;;
        11) set_newowner ;;
        0) break ;; 
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
echo -e "${CYAN}Exiting. Goodbye!${NC}"