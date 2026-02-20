#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE="$SCRIPT_DIR/config.conf"
CONFIG_DEST_DIR="$HOME/.config/mango"
CONFIG_DEST_FILE="$CONFIG_DEST_DIR/config.conf"

MANGOWC_REPO="${MANGOWC_REPO:-}"
NOCTALIA_REPO="${NOCTALIA_REPO:-}"
PKG_CACHE_READY=0
TOTAL_STEPS=5
CURRENT_STEP=0

command_exists() { command -v "$1" >/dev/null 2>&1; }
log_info()       { printf '[INFO] %s\n' "$*"; }
log_warn()       { printf '[WARN] %s\n' "$*"; }
log_error()      { printf '[ERROR] %s\n' "$*" >&2; }
die()            { log_error "$*"; exit 1; }
require_file()   { [[ -f "$1" ]] || die "Required file not found: $1"; }

SUDO="$(command_exists sudo && echo sudo || echo '')"

step() {
	CURRENT_STEP=$((CURRENT_STEP + 1))
	printf '\n[%d/%d] %s\n' "$CURRENT_STEP" "$TOTAL_STEPS" "$*"
}

trap 'log_error "Command failed at line $LINENO: $BASH_COMMAND"; exit $?' ERR

ensure_pkg_metadata() {
	local manager="$1"
	[[ "$PKG_CACHE_READY" -eq 1 ]] && return
	log_info "Refreshing $manager package metadata"
	case "$manager" in
		apt)    $SUDO apt-get update ;;
		dnf)    $SUDO dnf makecache ;;
		pacman) $SUDO pacman -Sy --noconfirm ;;
		zypper) $SUDO zypper --non-interactive refresh ;;
		*)      die "Unsupported package manager: $manager" ;;
	esac
	PKG_CACHE_READY=1
}

package_exists() {
	local manager="$1" package="$2"
	case "$manager" in
		apt)    apt-cache show "$package" >/dev/null 2>&1 ;;
		dnf)    dnf info "$package" >/dev/null 2>&1 ;;
		pacman) pacman -Si "$package" >/dev/null 2>&1 ;;
		zypper) zypper --non-interactive info "$package" >/dev/null 2>&1 ;;
		*)      return 1 ;;
	esac
}

package_installed() {
	local manager="$1" package="$2"
	case "$manager" in
		apt)        dpkg -s "$package" >/dev/null 2>&1 ;;
		dnf|zypper) rpm -q "$package" >/dev/null 2>&1 ;;
		pacman)     pacman -Q "$package" >/dev/null 2>&1 ;;
		*)          return 1 ;;
	esac
}

install_repo_package_if_available() {
	local manager="$1" package="$2" label="$3"
	if ! package_exists "$manager" "$package"; then
		log_warn "$package not found in $manager repositories"
		return 1
	fi
	log_info "Found $package, installing as $label"
	run_pkg_install "$manager" "$package"
	log_info "$label installed from package manager"
}

choose_first_available_package() {
	local manager="$1" label="$2"; shift 2
	for candidate in "$@"; do
		package_exists "$manager" "$candidate" && { echo "$candidate"; return 0; }
	done
	die "Could not find a package for $label in $manager repositories. Tried: $*"
}

choose_latest_pacman_wlroots_package() {
	package_exists pacman wlroots && { echo "wlroots"; return 0; }
	local latest="" latest_minor=-1 candidate
	while IFS= read -r candidate; do
		if [[ "$candidate" =~ ^wlroots0\.([0-9]+)$ ]] && (( BASH_REMATCH[1] > latest_minor )); then
			latest_minor="${BASH_REMATCH[1]}"
			latest="$candidate"
		fi
	done < <(pacman -Ssq '^wlroots0\.[0-9]+$' 2>/dev/null || true)
	[[ -n "$latest" ]] && { echo "$latest"; return 0; }
	die "Could not find a wlroots package in pacman repositories (expected wlroots or wlroots0.x)."
}

run_pkg_install() {
	local manager="$1"; shift
	ensure_pkg_metadata "$manager"
	log_info "Installing packages: $*"
	case "$manager" in
		apt)    $SUDO apt-get install -y "$@" ;;
		dnf)    $SUDO dnf install -y "$@" ;;
		pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
		zypper) $SUDO zypper --non-interactive install "$@" ;;
		*)      die "Unsupported package manager: $manager" ;;
	esac
}

install_optional_packages() {
	local manager="$1"; shift
	local available=() missing=()
	for pkg in "$@"; do
		if package_exists "$manager" "$pkg"; then available+=("$pkg")
		else missing+=("$pkg")
		fi
	done
	if ((${#available[@]} > 0)); then
		log_info "Installing optional packages: ${available[*]}"
		run_pkg_install "$manager" "${available[@]}"
	fi
	if ((${#missing[@]} > 0)); then
		log_warn "Optional packages not found in $manager repositories: ${missing[*]}"
	fi
}

try_install_aur_package() {
	local package="$1"
	if command_exists yay; then
		log_info "Trying AUR package $package via yay"
		yay -S --needed --noconfirm --answerdiff=None --answerclean=None "$package"
	elif command_exists paru; then
		log_info "Trying AUR package $package via paru"
		paru -S --needed --noconfirm "$package"
	else
		return 1
	fi
}

install_noctalia_manual_release() {
	local target_dir="$HOME/.config/quickshell/noctalia-shell"
	local release_url="https://github.com/noctalia-dev/noctalia-shell/releases/latest/download/noctalia-latest.tar.gz"
	command_exists curl || die "curl is required for manual Noctalia installation"
	command_exists tar  || die "tar is required for manual Noctalia installation"
	log_info "Installing Noctalia shell manually to $target_dir"
	mkdir -p "$target_dir"
	curl -fsSL "$release_url" | tar -xz --strip-components=1 -C "$target_dir"
	log_info "Noctalia shell installed to $target_dir"
}

install_noctalia_from_repo() {
	local target_dir="$HOME/.config/quickshell/noctalia-shell"
	log_info "Cloning Noctalia shell from $1"
	rm -rf "$target_dir"
	git clone --depth=1 "$1" "$target_dir"
	log_info "Noctalia shell cloned to $target_dir"
}

install_dependencies() {
	local manager="$1"
	step "Installing MangoWC dependencies with $manager"
	case "$manager" in
		apt)
			run_pkg_install "$manager" \
				build-essential git meson ninja-build pkg-config cmake curl \
				wayland-protocols libwayland-dev libxkbcommon-dev libpixman-1-dev \
				libdrm-dev libinput-dev libxcb1-dev libxcb-composite0-dev \
				libxcb-xfixes0-dev libxcb-res0-dev libxcb-icccm4-dev \
				libxcb-ewmh-dev libxcb-errors-dev libseat-dev libcairo2-dev \
				libpango1.0-dev libpam0g-dev xwayland mate-polkit
			install_optional_packages "$manager" \
				libdisplay-info-dev libliftoff-dev hwdata libpcre2-dev libscenefx-dev
			;;
		dnf)
			run_pkg_install "$manager" \
				@development-tools git meson ninja-build pkgconf-pkg-config cmake curl \
				wayland-devel wayland-protocols-devel libxkbcommon-devel pixman-devel \
				libdrm-devel libinput-devel libxcb-devel xcb-util-devel \
				xcb-util-wm-devel xcb-util-errors-devel seatd-devel cairo-devel \
				pango-devel pam-devel xorg-x11-server-Xwayland mate-polkit
			install_optional_packages "$manager" \
				libdisplay-info-devel libliftoff-devel hwdata pcre2-devel scenefx-devel
			;;
		pacman)
			local wlroots_pkg libseat_pkg
			wlroots_pkg="$(choose_latest_pacman_wlroots_package)"
			libseat_pkg="$(choose_first_available_package "$manager" "libseat" libseat seatd)"
			log_info "Using wlroots: $wlroots_pkg  libseat: $libseat_pkg"

			run_pkg_install "$manager" \
				base-devel git meson ninja pkgconf cmake curl wayland \
				wayland-protocols "$wlroots_pkg" xorg-xwayland libxkbcommon pixman libdrm \
				libinput libxcb xcb-util xcb-util-wm xcb-util-errors "$libseat_pkg" cairo \
				pango pam mate-polkit
			install_optional_packages "$manager" \
				libdisplay-info libliftoff hwdata pcre2 scenefx scenefx-git
			;;
		zypper)
			run_pkg_install "$manager" \
				-t pattern devel_basis
			run_pkg_install "$manager" \
				git meson ninja pkg-config cmake curl wayland-devel \
				wayland-protocols-devel wlroots-devel libxkbcommon-devel \
				pixman-devel libdrm-devel libinput-devel libxcb-devel \
				xcb-util-devel xcb-util-wm-devel seatd-devel cairo-devel \
				pango-devel pam-devel xwayland mate-polkit
			install_optional_packages "$manager" \
				libdisplay-info-devel libliftoff-devel hwdata pcre2-devel scenefx-devel
			;;
		*)
			die "Unsupported package manager: $manager"
			;;
	esac
}

detect_pkg_manager() {
	command_exists apt-get && { echo apt; return; }
	for manager in dnf pacman zypper; do
		command_exists "$manager" && { echo "$manager"; return; }
	done
	echo ""
}

build_mangowc_from_source() {
	local tmp_dir; tmp_dir="$(mktemp -d)"
	local repo_dir="$tmp_dir/mangowc"
	log_info "Building MangoWC from source: $1"
	git clone --depth=1 "$1" "$repo_dir"
	(cd "$repo_dir" && meson setup build && ninja -C build && $SUDO ninja -C build install)
	rm -rf "$tmp_dir"
}

install_mangowc() {
	local manager="$1"
	step "Installing MangoWC"
	command_exists mangowc && { log_info "MangoWC is already installed"; return; }

	if install_repo_package_if_available "$manager" mangowc "MangoWC"; then return; fi

	if [[ "$manager" == "pacman" ]]; then
		if try_install_aur_package mangowc-git; then
			log_info "MangoWC installed from AUR package"
			return
		fi
		log_warn "Could not install mangowc-git via AUR helper"
	fi

	[[ -z "$MANGOWC_REPO" ]] && die "Could not install mangowc from package manager/AUR. Set MANGOWC_REPO to a valid git URL to build from source."
	build_mangowc_from_source "$MANGOWC_REPO"
}

install_config() {
	step "Installing config.conf"
	log_info "Installing config.conf to $CONFIG_DEST_FILE"
	mkdir -p "$CONFIG_DEST_DIR"
	install -m 644 "$CONFIG_SOURCE" "$CONFIG_DEST_FILE"
}

run_post_install_checks() {
	local manager="$1"
	local noctalia_dir="$HOME/.config/quickshell/noctalia-shell"
	local failures=0
	step "Running post-install checks"

	if command_exists mangowc || command_exists mango; then
		log_info "MangoWC binary check passed"
	else
		log_error "MangoWC binary not found (expected 'mangowc' or 'mango' in PATH)"
		failures=$((failures + 1))
	fi

	if [[ -f "$CONFIG_DEST_FILE" ]]; then
		log_info "Mango config check passed: $CONFIG_DEST_FILE"
	else
		log_error "Mango config check failed: missing $CONFIG_DEST_FILE"
		failures=$((failures + 1))
	fi

	if command_exists noctalia-shell || package_installed "$manager" noctalia-shell; then
		log_info "Noctalia shell check passed"
	elif [[ -d "$noctalia_dir" ]]; then
		if command_exists qs; then
			log_info "Noctalia manual install found: $noctalia_dir  (launch: qs -p $noctalia_dir)"
		else
			log_warn "Noctalia files found at $noctalia_dir, but 'qs' is not installed"
		fi
	else
		log_warn "Noctalia shell was not detected in PATH or manual install directory"
	fi

	((failures > 0)) && die "Post-install checks failed ($failures issue(s))."
	log_info "Post-install checks completed"
}

setup_noctalia() {
	local manager="$1"
	step "Setting up Noctalia"
	ensure_pkg_metadata "$manager"

	if install_repo_package_if_available "$manager" noctalia-shell "Noctalia shell"; then return; fi

	if [[ "$manager" == "pacman" ]]; then
		if try_install_aur_package noctalia-shell || try_install_aur_package noctalia-shell-git; then
			log_info "Noctalia shell installed from AUR package"
			return
		fi
		log_warn "Could not install noctalia-shell via AUR helper"
	fi

	if [[ -n "$NOCTALIA_REPO" ]]; then
		install_noctalia_from_repo "$NOCTALIA_REPO"
		return
	fi

	install_noctalia_manual_release
}

main() {
	require_file "$CONFIG_SOURCE"
	local manager; manager="$(detect_pkg_manager)"
	[[ -z "$manager" ]] && die "No supported package manager found (apt, dnf, pacman, zypper)."
	log_info "Detected package manager: $manager"

	install_dependencies "$manager"
	install_mangowc "$manager"
	install_config
	setup_noctalia "$manager"
	run_post_install_checks "$manager"

	printf '\n'
	log_info "All tasks completed successfully"
}

main "$@"
