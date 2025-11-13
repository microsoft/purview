#!/bin/bash
#
# DisplayDlpPolicy for macOS
# Mimics Windows DisplayDlpPolicy.exe -status output
#
# This script extracts DLP policy information from macOS and formats it
# similar to the Windows DisplayDlpPolicy.exe tool
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Path to DLP diagnostic tool
DLP_DIAGNOSTIC="/Library/Application Support/Microsoft/DLP/com.microsoft.dlp.daemon.app/Contents/Resources/Tools/dlp_diagnostic.py"
DLP_POLICY_BIN="/Library/Application Support/Microsoft/DLP/policy/dlp_policy.bin"

# Temporary file for policy info
TEMP_POLICY_INFO=$(mktemp)

# Function to display usage information
show_usage() {
    echo -e "${BLUE}DisplayDlpPolicy for macOS${NC}"
    echo ""
    echo "DESCRIPTION:"
    echo "  Extracts and displays Microsoft Defender for Endpoint DLP policy information"
    echo "  from macOS devices. Mimics the Windows DisplayDlpPolicy.exe -status output."
    echo ""
    echo "  Primary purpose: List DLP rules and last policy sync time to assist in"
    echo "  troubleshooting Microsoft Purview Endpoint DLP on macOS."
    echo ""
    echo -e "  ${YELLOW}NOTE: This initial version only implements 'DisplayDlpPolicy.exe -status' output.${NC}"
    echo "        Additional DisplayDlpPolicy.exe options are not yet supported."
    echo ""
    echo "USAGE:"
    echo "  sudo $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Display this help message and exit"
    echo "  -v, --version  Display version information and exit"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - macOS operating system"
    echo "  - Microsoft Defender for Endpoint installed"
    echo "  - Root/sudo privileges"
    echo "  - Python 3 installed"
    echo ""
    echo "EXAMPLES:"
    echo "  sudo ./DisplayDlpPolicy.sh"
    echo "  sudo bash DisplayDlpPolicy.sh"
    echo ""
    echo "OUTPUT:"
    echo "  - DLP policy file information (location, last modified)"
    echo "  - Last policy sync time"
    echo "  - Policy details (name, ID, status)"
    echo "  - Configured DLP rules and restrictions"
    echo ""
    echo "USE CASES:"
    echo "  - Verify DLP policy is syncing correctly"
    echo "  - Check which rules are active on the device"
    echo "  - Troubleshoot policy deployment issues"
    echo "  - Confirm policy updates have been applied"
    echo ""
    echo "WINDOWS EQUIVALENT:"
    echo "  DisplayDlpPolicy.exe -status"
    echo ""
    echo "FILES:"
    echo "  Policy File: $DLP_POLICY_BIN"
    echo "  Diagnostic Tool: $DLP_DIAGNOSTIC"
    echo ""
}

# Function to display version
show_version() {
    echo "DisplayDlpPolicy for macOS v1.0"
    echo "Compatible with Microsoft Defender for Endpoint DLP"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -v|--version)
        show_version
        exit 0
        ;;
    "")
        # No arguments, continue with normal execution
        ;;
    *)
        echo -e "${RED}Error: Unknown option '$1'${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script is designed for macOS only${NC}"
    echo "Detected OS: $(uname)"
    echo ""
    echo "For Windows, use DisplayDlpPolicy.exe instead."
    exit 1
fi

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run with sudo${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if DLP diagnostic tool exists
if [ ! -f "$DLP_DIAGNOSTIC" ]; then
    echo -e "${RED}Error: DLP diagnostic tool not found at:${NC}"
    echo "$DLP_DIAGNOSTIC"
    echo ""
    echo "Please ensure Microsoft Defender for Endpoint is installed."
    exit 1
fi

# Check if policy file exists
if [ ! -f "$DLP_POLICY_BIN" ]; then
    echo -e "${YELLOW}Warning: DLP policy file not found at:${NC}"
    echo "$DLP_POLICY_BIN"
    echo ""
    echo "DLP may not be configured on this device."
fi

# Display policy file timestamp
if [ -f "$DLP_POLICY_BIN" ]; then
    echo -e "${GREEN}DLP Policy File Information:${NC}"
    echo "Location: $DLP_POLICY_BIN"
    echo -n "Last Modified: "
    stat -f "%Sm" "$DLP_POLICY_BIN"
    echo ""
fi

# Extract policy information
echo -e "${GREEN}Extracting DLP policy information...${NC}"
sudo "$DLP_DIAGNOSTIC" --policy-info > "$TEMP_POLICY_INFO" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to extract policy information${NC}"
    cat "$TEMP_POLICY_INFO"
    rm -f "$TEMP_POLICY_INFO"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Format and display the output
python3 "$SCRIPT_DIR/format_dlp_policy.py" "$TEMP_POLICY_INFO"

# Clean up
rm -f "$TEMP_POLICY_INFO"

echo ""
echo -e "${GREEN}Policy extraction complete.${NC}"
