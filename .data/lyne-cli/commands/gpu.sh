# lyne gpu - The graphics cards of this machine

local subcmd="${1:-status}"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne gpu [status|--json]"
        echo ""
        echo "Lists the GPUs found in sysfs: integrated or dedicated, the NVIDIA"
        echo "generation and the driver branch that supports it, the kernel driver in"
        echo "use and the outputs of each GPU (the card numbers change between boots)."
        echo ""
        echo "Subcommands:"
        echo "  status    Readable list (default)"
        echo "  --json    The same as JSON"
        ;;
    status|--json|json)
        source "$DOTS_DIR/.data/lyne-cli/lib/gpus.sh"
        gpu_detect
        if [[ "$subcmd" == status ]]; then
            gpu_status
        else
            gpu_json
        fi
        ;;
    *)
        echo "lyne gpu: unknown subcommand '$subcmd'"
        echo "Run 'lyne gpu --help' for usage information."
        return 1
        ;;
esac
