termux_step_massage() {
	[ "$TERMUX_PKG_METAPACKAGE" = "true" ] && return

	local file

	cd "$TERMUX_PKG_MASSAGEDIR/$TERMUX_PREFIX_CLASSICAL"

	local ADDING_PREFIX=""
	if [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
		ADDING_PREFIX="glibc/"
	fi

	# Remove lib/charset.alias which is installed by gettext-using packages:
	rm -f lib/charset.alias

	# Remove cache file created by update-desktop-database:
	rm -f share/applications/mimeinfo.cache

	# Remove cache file created by glib-compile-schemas:
	rm -f share/glib-2.0/schemas/gschemas.compiled

	# Remove cache file generated when using glib-cross-bin:
	rm -rf opt/glib/cross/share/glib-2.0/codegen/__pycache__

 	# Removing the pacman log that is often included in the package:
  	rm -f var/log/pacman.log

	# Remove cache file created by gtk-update-icon-cache:
	rm -f share/icons/hicolor/icon-theme.cache

	# Remove locale files we're not interested in:
	rm -Rf share/locale

	# Remove ldconfig cache:
	rm -f glibc/etc/ld{,32}.so.cache
	rm -rf glibc/var/cache/ldconfig{,32}

	# `update-mime-database` updates NOT ONLY "$PREFIX/share/mime/mime.cache".
	# Simply removing this specific file does not solve the issue.
	if [ -e "share/mime/mime.cache" ]; then
		termux_error_exit "MIME cache found in package. Please disable \`update-mime-database\`."
	fi

	# Remove old kept libraries (readline) and directories (rust):
	find . -name '*.old' -print0 | xargs -0 -r rm -fr

	# Move over sbin to bin:
	for file in sbin/*; do if test -f "$file"; then mv "$file" bin/; fi; done
	if [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
		for file in glibc/sbin/*; do if test -f "$file"; then mv "$file" glibc/bin/; fi; done
	fi

	# Remove world permissions and make sure that user still have read-write permissions.
	chmod -Rf u+rw,g-rwx,o-rwx . || true

	if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ]; then
		if [ "$TERMUX_PKG_NO_STRIP" != "true" ] && [ "$TERMUX_DEBUG_BUILD" = "false" ]; then
			termux_step_strip_elf_symbols
		fi

		if [ "$TERMUX_PKG_NO_ELF_CLEANER" != "true" ]; then
			termux_step_elf_cleaner
		fi
	fi

	if [ "$TERMUX_PKG_NO_SHEBANG_FIX" != "true" ]; then
		local no_shebang_replace_full_regex="" no_shebang_replace_regex
		# Assume files are a regex list and special characters in paths in each regex are already escaped.
		if [[ -n "$TERMUX_PKG_NO_SHEBANG_FIX_FILES" ]]; then
			while IFS= read -r no_shebang_replace_regex; do
				[[ -n "$no_shebang_replace_full_regex" ]] && no_shebang_replace_full_regex+='|'
				no_shebang_replace_full_regex+="($no_shebang_replace_regex)"
			done < <(printf "%s\n" "$TERMUX_PKG_NO_SHEBANG_FIX_FILES")
			if [[ -n "$no_shebang_replace_full_regex" ]]; then
				no_shebang_replace_full_regex='(|./)('"$no_shebang_replace_full_regex"')$'
			fi
		fi

		local prefix_escaped shebang_already_valid_regex header_line shebang_match
		local shebang_regex='^#!.*/bin/.*'

		# Escape '\$[](){}|^.?+*' with backslashes.
		prefix_escaped="$(printf "%s" "$TERMUX_PREFIX_CLASSICAL" | sed -zE -e 's/[][\.|$(){}?+*^]/\\&/g')"
		shebang_already_valid_regex='^#! ?((/system/)|('"$prefix_escaped"'/))'

		# Fix shebang paths:
		while IFS= read -rd '' file; do
			# Ideally the shebang length should be limited to `BINPRM_BUF_SIZE = 256` for Linux kernel `>= 5.1`,
			# but Termux increases the limit to `TERMUX__FILE_HEADER__BUFFER_SIZE = 340` with `termux-exec` to
			# accommodate for longer `TERMUX__ROOTFS` as per `TERMUX__ROOTFS_DIR___MAX_LEN = 86` (check `ExecIntercept.h`).
			# However, a package may use the build directory path for dynamically setting the shebang at build time,
			# so use `PATH_MAX = 4096` as length limit instead, as a shorter limit like `256`/`340` may prevent reading the
			# entire header line if build directory path is longer and `shebang_regex` will fail to match and skip shebang
			# replacement. Additionally, we first read first `2` characters and see if they match `#!`, before reading
			# rest of the header line to avoid wasting time reading `4096` characters for non-shebang files.
			# `|| :` is used for second `read` to include files with just a shebang line as `read` will exit with `1` for those due to EOF.
			# For example, `pip` from `python-pip` package is set with the following shebang at build time:
			# `#!/home/builder/.termux-build/python3.12-crossenv-prefix-bionic-x86_64/cross/bin/python3.12`
			header_line=""
			{ { read -r -n 2 header_line && [[ "$header_line" == "#!" ]]; } || continue; read -r -n 4096 header_line || :; } < "$file"
			header_line="#!${header_line}"
			if [[ "${#header_line}" -ge 3 && "$header_line" =~ $shebang_regex ]]; then
				shebang_match="${BASH_REMATCH[0]}"
				if [[ -n "$shebang_match" ]]; then
					if [[ "$shebang_match" =~ $shebang_already_valid_regex ]]; then
						echo "INFO: Skip shebang fix for '$file' as shebang '$shebang_match' already valid"
						continue
					fi
					if [[ -n "$no_shebang_replace_full_regex" ]] && [[ "$file" =~ $no_shebang_replace_full_regex ]]; then
						echo "INFO: Skip shebang fix for '$file' as its excluded"
						continue
					fi
					sed --follow-symlinks -i -E "1 s@^#\!(.*)/bin/(.*)@#\!$TERMUX_PREFIX/bin/\2@" "$file"
				fi
			fi
		done < <(find . -type f -print0)
	fi

	# Delete the info directory file.
	rm -rf ./${ADDING_PREFIX}share/info/dir

	# Mostly specific to X11-related packages.
	rm -f ./${ADDING_PREFIX}share/icons/hicolor/icon-theme.cache

	test ! -z "$TERMUX_PKG_RM_AFTER_INSTALL" && rm -Rf $TERMUX_PKG_RM_AFTER_INSTALL

	find . -type d -empty -delete # Remove empty directories

	if [ -d ./${ADDING_PREFIX}share/man ]; then
		# Remove non-english man pages:
		find ./${ADDING_PREFIX}share/man -mindepth 1 -maxdepth 1 -type d ! -name man\* | xargs -r rm -rf

		# Compress man pages with gzip:
		find ./${ADDING_PREFIX}share/man -type f ! -iname \*.gz -print0 | xargs -r -0 gzip -9 -n

		# Update man page symlinks, e.g. unzstd.1 -> zstd.1:
		while IFS= read -r -d '' file; do
			local _link_value
			_link_value=$(readlink $file)
			rm $file
			ln -s $_link_value.gz $file.gz
		done < <(find ./${ADDING_PREFIX}share/man -type l ! -iname \*.gz -print0)
	fi

	# Remove python-glibc package files that are created
	# due to its launch during package compilation.
	if [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ] && [ "$TERMUX_PKG_NAME" != "python-glibc" ]; then
		rm -f ./${ADDING_PREFIX}lib/python${TERMUX_PYTHON_VERSION}/__pycache__/{base64,platform,quopri}.cpython-${TERMUX_PYTHON_VERSION//./}.pyc
	fi

	# Check so files were actually installed. Exclude
	# share/doc/$TERMUX_PKG_NAME/ as a license file is always
	# installed there.
	if [ "$(find . -path "./${ADDING_PREFIX}share/doc/$TERMUX_PKG_NAME" -prune -o -type f -print | head -n1)" = "" ]; then
		if [ -f "$TERMUX_PKG_SRCDIR"/configure.ac -o -f "$TERMUX_PKG_SRCDIR"/configure.in ]; then
			termux_error_exit "No files in package. Maybe you need to run autoreconf -fi before configuring."
		else
			termux_error_exit "No files in package."
		fi
	fi

	local HARDLINKS
	HARDLINKS="$(find . -type f -links +1)"
	if [ -n "$HARDLINKS" ]; then
		if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ]; then
			termux_error_exit "Package contains hard links: $HARDLINKS"
		elif [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
			local declare hard_list
			for i in $HARDLINKS; do
				hard_list[$(ls -i "$i" | awk '{printf $1}')]+="$i "
			done
			local root_file
			for i in ${!hard_list[@]}; do
				root_file=""
				for j in ${hard_list[$i]}; do
					if [ -z "$root_file" ]; then
						root_file="$j"
						continue
					fi
					ln -sf "${TERMUX_PREFIX_CLASSICAL}/${root_file:2}" "${j}"
				done
			done
		fi
	fi

	# Remove duplicate headers from `include32/` directory
	if [[ -d ./${ADDING_PREFIX}/include32 && -d ${TERMUX__PREFIX__BASE_INCLUDE_DIR} ]]; then
		local hpath
		for hpath in $(find ./${ADDING_PREFIX}/include32 -type f); do
			local h=$(sed "s|./${ADDING_PREFIX}/include32/||g" <<< "$hpath")
			if [[ -f "${TERMUX__PREFIX__BASE_INCLUDE_DIR}/${h}" && \
				"$(md5sum < "${hpath}")" = "$(md5sum < "${TERMUX__PREFIX__BASE_INCLUDE_DIR}/${h}")" ]]; then
				rm "${hpath}"
			fi
		done
	fi

	# Configure pkgconfig files for proper multilib-compilation
	if [[ -d ./${ADDING_PREFIX}/lib32/pkgconfig ]]; then
		local pc
		for pc in $(grep -s -r -l "^includedir=.*/include32" ./${ADDING_PREFIX}/lib32/pkgconfig); do
			local pc_cflags="$(grep '^Cflags:' "${pc}" | awk -F ':' '{printf $2 "\n"}')"
			if ! grep -q ' -I' <<< "${pc_cflags}"; then
				continue
			fi
			local pc_multilib_path="$(grep '^includedir=' "${pc}" | sed "s|${TERMUX_PREFIX}|\${prefix}|g" | awk -F '{prefix}/include' '{printf $2}')"
			local pc_edit_cflags="$(sed "s|\${includedir}|\${includedir}${pc_multilib_path}|g" <<< "${pc_cflags}")"
			local pc_new_cflags="$(tr ' ' '\n' <<< "${pc_edit_cflags}" | sed 's|\({includedir}\)32|\1|gp; s|\(/include\)32|\1|gp; d' | tr '\n' ' ')"
			sed -i -e "s|\(^includedir=.*/\)include32\(.*\)|\1include|g" \
				-e "s|^Cflags:${pc_cflags}$|Cflags:${pc_edit_cflags} ${pc_new_cflags::-1}|g" \
				"${pc}"
			# Apply the modified pkgconfig to the system for proper multilib-compilation work
			cp -r "${pc}" "${TERMUX__PREFIX__MULTI_LIB_DIR}/pkgconfig"
		done
	fi

	# Check for directory "$PREFIX/man" which indicates packaging error.
	if [ -d "./${ADDING_PREFIX}man" ]; then
		termux_error_exit "Package contains directory \"\$PREFIX/man\" ($TERMUX_PREFIX/man). Use \"\$PREFIX/share/man\" ($TERMUX_PREFIX/share/man) instead."
	fi

	# Check for directory "$PREFIX/$PREFIX" which almost always indicates
	# packaging error.
	if [ -d "./${TERMUX_PREFIX#/}" ]; then
		termux_error_exit "Package contains directory \"\$PREFIX/\$PREFIX\" ($TERMUX_PREFIX/${TERMUX_PREFIX#/})"
	fi

	# Check for Debianish Python directory which indicates packaging error.
	local _python_deb_install_layout_dir="${ADDING_PREFIX}lib/python3/dist-packages"
	if [ -d "./${_python_deb_install_layout_dir}" ]; then
		termux_error_exit "Package contains directory \"\$PREFIX/${_python_deb_install_layout_dir}\" ($TERMUX_PREFIX/${_python_deb_install_layout_dir})"
	fi

	# Check so that package is not affected by
	# https://github.com/android/ndk/issues/1614, or
	# https://github.com/termux/termux-packages/issues/9944
	if [[ "${TERMUX_PACKAGE_LIBRARY}" == "bionic" ]]; then
		echo "INFO: READELF=${READELF} ... $(command -v ${READELF})"
		export pattern_file_undef=$(mktemp)
		echo "INFO: Generating undefined symbols regex to ${pattern_file_undef}"
		local t0=$(get_epoch)
		local SYMBOLS=$(${READELF} -s $(${TERMUX_HOST_PLATFORM}-clang -print-libgcc-file-name) | grep -E "FUNC[[:space:]]+GLOBAL[[:space:]]+HIDDEN" | awk '{ print $8 }')
		SYMBOLS+=" $(echo libandroid_{sem_{open,close,unlink},shm{ctl,get,at,dt}})"
		SYMBOLS+=" $(grep "^    [_a-zA-Z0-9]*;" ${TERMUX_SCRIPTDIR}/scripts/lib{c,dl,m}.map.txt | cut -d":" -f2 | sed -e "s/^    //" -e "s/;.*//")"
		SYMBOLS+=" ${TERMUX_PKG_EXTRA_UNDEF_SYMBOLS_TO_CHECK}"
		SYMBOLS=$(echo $SYMBOLS | tr " " "\n" | sort | uniq)
		create_grep_pattern_undef ${SYMBOLS} > "${pattern_file_undef}"
		local t1=$(get_epoch)
		echo "INFO: Done ... $((t1-t0))s"
		echo "INFO: Total symbols $(echo ${SYMBOLS} | wc -w)"
		export pattern_file_openmp=$(mktemp)
		echo "INFO: Generating OpenMP symbols regex to ${pattern_file_openmp}"
		local t0=$(get_epoch)
		local LIBOMP_SO=$(${TERMUX_HOST_PLATFORM}-clang -print-file-name=libomp.so)
		local LIBOMP_A=$(${TERMUX_HOST_PLATFORM}-clang -print-file-name=libomp.a)
		[[ "${LIBOMP_SO}" == "libomp.so" ]] && echo "WARN: LIBOMP_SO=${LIBOMP_SO}, discarding" >&2 && LIBOMP_SO=""
		[[ "${LIBOMP_A}" == "libomp.a" ]] && echo "WARN: LIBOMP_A=${LIBOMP_A}, discarding" >&2 && LIBOMP_A=""
		export LIBOMP_SO_SYMBOLS='' LIBOMP_A_SYMBOLS='' LIBOMP_SYMBOLS=''
		[[ -n "${LIBOMP_SO}" ]] && LIBOMP_SO_SYMBOLS=$(${READELF} -s "${LIBOMP_SO}" | grep -E "GLOBAL[[:space:]]+DEFAULT" | grep -vE "[[:space:]]UND[[:space:]]" | grep -vE "[[:space:]]sizes$" | awk '{ print $8 }')
		[[ -n "${LIBOMP_A}" ]] && LIBOMP_A_SYMBOLS=$(${READELF} -s "${LIBOMP_A}" | grep -E "GLOBAL[[:space:]]+DEFAULT" | grep -vE "[[:space:]]UND[[:space:]]" | grep -vE "[[:space:]]sizes$" | awk '{ print $8 }')
		LIBOMP_SYMBOLS=$(echo -e "${LIBOMP_SO_SYMBOLS}\n${LIBOMP_A_SYMBOLS}" | sort | uniq)
		create_grep_pattern_openmp ${LIBOMP_SYMBOLS} > "${pattern_file_openmp}"
		local t1=$(get_epoch)
		echo "INFO: Done ... $((t1-t0))s"
		echo "INFO: Total OpenMP symbols $(echo ${LIBOMP_SYMBOLS} | wc -w)"

		local nproc=1
		echo "INFO: Identifying files with nproc=${nproc}"
		local t0=$(get_epoch)
		local files; files="$(IFS=; find . -type f -print0 | \
			while read -r -d '' file; do
				# Find files with ELF or static library signature in the first 4 bytes bytes
				read -rN4 hdr < "$file" || continue
				[[ $hdr == $'\x7fELF' || $hdr == '!<ar' ]] && printf '%s\n' "$file" || :
			done
		)"
		# use bash to see if llvm-readelf crash
		# https://github.com/llvm/llvm-project/issues/89534
		local valid=$(echo "${files}" | xargs -P"${nproc}" -i bash -c 'if ${READELF} -h "{}" &>/dev/null; then echo "{}"; fi')
		local t1=$(get_epoch)
		echo "INFO: Done ... $((t1-t0))s"
		local numberOfFiles=$(echo "${files}" | wc -l)
		local numberOfValid=$(echo "${valid}" | wc -l)
		echo "INFO: Found ${numberOfValid} / ${numberOfFiles} files"
		if [[ "${numberOfValid}" -gt "${numberOfFiles}" ]]; then
			termux_error_exit "${numberOfValid} > ${numberOfFiles}"
		fi

		echo "INFO: Running symbol checks on ${numberOfValid} files with nproc=${nproc}"
		local t0=$(get_epoch)
		local undef=$(echo "${valid}" | xargs -P"${nproc}" -i sh -c '${READELF} -s "{}" | grep -Ef "${pattern_file_undef}"')
		local openmp=$(echo "${valid}" | xargs -P"${nproc}" -i sh -c '${READELF} -s "{}" | grep -Ef "${pattern_file_openmp}"')
		local depend_libomp_so=$(echo "${valid}" | xargs -P$(nproc) -n1 ${READELF} -d 2>/dev/null | sed -ne "s|.*NEEDED.*\[\(.*\)\].*|\1|p" | grep libomp.so)
		local t1=$(get_epoch)
		echo "INFO: Done ... $((t1-t0))s"

		[[ -n "${undef}" ]] && echo "INFO: Found files with undefined symbols"
		if [[ "${TERMUX_PKG_UNDEF_SYMBOLS_FILES}" == "all" ]]; then
			echo "INFO: Skipping output result as TERMUX_PKG_UNDEF_SYMBOLS_FILES=all"
			undef=""
		fi

		if [[ -n "${undef}" ]]; then
			echo "INFO: Showing result"
			local t0=$(get_epoch)
			# e: bit0 valid file, bit1 error handling
			local e=0
			local c=0
			local valid_s=$(echo "${valid}" | sort)
			local excluded_file
			while IFS= read -r file; do
				# exclude object, static files
				case "${file}" in
				*.a) (( e &= ~1 )) || : ;;
				*.dll) (( e &= ~1 )) || : ;;
				*.o) (( e &= ~1 )) || : ;;
				*.obj) (( e &= ~1 )) || : ;;
				*.rlib) (( e &= ~1 )) || : ;;
				*.syso) (( e &= ~1 )) || : ;;
				*) (( e |= 1 )) || : ;;
				esac
				while IFS= read -r excluded_file; do
					[[ "${file}" == ${excluded_file} ]] && (( e &= ~1 )) && break
				done < <(echo "${TERMUX_PKG_UNDEF_SYMBOLS_FILES}")
				[[ "${TERMUX_PKG_UNDEF_SYMBOLS_FILES}" == "error" ]] && (( e |= 1 )) || :
				[[ $(( e & 1 )) == 0 ]] && echo "SKIP: ${file}" && continue
				local undef_sym=$(${READELF} -s "${file}" | grep -Ef "${pattern_file_undef}")
				if [[ -n "${undef_sym}" ]]; then
					((c++)) || :
					if [[ $(( e & 1 )) != 0 ]]; then
						echo -e "ERROR: ${file} contains undefined symbols:\n${undef_sym}" >&2
						(( e |= 2 )) || :
					else
						local undef_symu=$(echo "${undef_sym}" | awk '{ print $8 }' | sort | uniq)
						local undef_symu_len=$(echo ${undef_symu} | wc -w)
						echo "SKIP: ${file} contains undefined symbols: ${undef_symu_len}" >&2
					fi
				fi
			done < <(echo "${valid_s}")
			local t1=$(get_epoch)
			echo "INFO: Done ... $((t1-t0))s"
			echo "INFO: Found ${c} files with undefined symbols after exclusion"
			[[ "${c}" -gt "${numberOfValid}" ]] && termux_error_exit "${c} > ${numberOfValid}"
			[[ $(( e & 2 )) != 0 ]] && termux_error_exit "Refer above"
		fi

		if [[ -n "${openmp}" ]]; then
			echo "INFO: Found files with OpenMP symbols"
			echo "INFO: Showing result"
			local t0=$(get_epoch)
			# e: bit0 valid file, bit1 error handling
			local e=0
			local c=0
			local valid_s=$(echo "${valid}" | sort)
			while IFS= read -r file; do
				# exclude object, static files
				case "${file}" in
				*.a) (( e &= ~1 )) || : ;;
				*.dll) (( e &= ~1 )) || : ;;
				*.o) (( e &= ~1 )) || : ;;
				*.obj) (( e &= ~1 )) || : ;;
				*.rlib) (( e &= ~1 )) || : ;;
				*.syso) (( e &= ~1 )) || : ;;
				*) (( e |= 1 )) || : ;;
				esac
				[[ $(( e & 1 )) == 0 ]] && echo "SKIP: ${file}" && continue
				local openmp_sym=$(${READELF} -s "${file}" | grep -Ef "${pattern_file_openmp}")
				if [[ -n "${openmp_sym}" ]]; then
					((c++)) || :
					echo -e "INFO: ${file} contains OpenMP symbols: $(echo "${openmp_sym}" | wc -l)" >&2
				fi
			done < <(echo "${valid_s}")
			local t1=$(get_epoch)
			echo "INFO: Done ... $((t1-t0))s"
			echo "INFO: Found ${c} files with OpenMP symbols after exclusion"
			[[ "${c}" -gt "${numberOfValid}" ]] && termux_error_exit "${c} > ${numberOfValid}"
		fi
		if [[ -n "${depend_libomp_so}" && "${TERMUX_PKG_NO_OPENMP_CHECK}" != "true" ]]; then
			echo "ERROR: Found files depend on libomp.so" >&2
			echo "ERROR: Showing result" >&2
			local t0=$(get_epoch)
			local valid_s=$(echo "${valid}" | sort)
			{
				while IFS= read -r file; do
					local needed_file=$(${READELF} -d "${file}" 2>/dev/null | sed -ne "s|.*NEEDED.*\[\(.*\)\].*|\1|p" | sort | uniq | tr "\n" " " | sed -e "s/ /, /g")
					echo "ERROR: ${file}: ${needed_file%, }"
				done < <(echo "${valid_s}")
			} | grep libomp.so >&2
			local t1=$(get_epoch)
			echo "ERROR: Done ... $((t1-t0))s" >&2
			termux_error_exit "Refer above"
		fi

		rm -f "${pattern_file_undef}" "${pattern_file_openmp}"
		unset pattern_file_undef pattern_file_openmp
	fi

	if [ "$TERMUX_PACKAGE_FORMAT" = "debian" ]; then
		termux_create_debian_subpackages
	elif [ "$TERMUX_PACKAGE_FORMAT" = "pacman" ]; then
		termux_create_pacman_subpackages
	fi

	# .. remove empty directories (NOTE: keep this last):
	find . -type d -empty -delete
}

# Local function called by termux_step_massage
create_grep_pattern_undef() {
	local symbol_type='NOTYPE[[:space:]]+GLOBAL[[:space:]]+DEFAULT[[:space:]]+UND[[:space:]]+'
	echo -n "$symbol_type$1"'$'
	shift 1
	local arg
	for arg in "$@"; do
		echo -n "|$symbol_type$arg"'$'
	done
}

create_grep_pattern_openmp() {
	local symbol_type='[[:space:]]'
	echo -n "$symbol_type$1"'$|'"$symbol_type$1"'@VERSION$'
	shift 1
	local arg
	for arg in "$@"; do
		echo -n "|$symbol_type$arg"'$|'"$symbol_type$arg"'@VERSION$'
	done
}

get_epoch() {
	[[ -e /proc/uptime ]] && cut -d"." -f1 /proc/uptime && return
	[[ -n "$(command -v date)" ]] && date +%s && return
	echo 0
}
