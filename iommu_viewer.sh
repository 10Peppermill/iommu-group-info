#!/bin/bash

# Print a message to the console to inform the user that the script is running.
echo "Please be patient. This may take a couple seconds."

# Declare an associative array to hold the lines for each IOMMU group, and set the field_delimiter to "|".
declare -A iommu_group_lines
field_delimiter="|"

# Loop through each IOMMU group.
for iommu_group in $(find /sys/kernel/iommu_groups/ -maxdepth 1 -mindepth 1 -type d | sed 's/.*iommu_groups\///'); do
    # For each device in the group, add its lspci output to the group's lines in the associative array.
    for iommu_group_device in $(find /sys/kernel/iommu_groups/$iommu_group/devices/* -maxdepth 0 -mindepth 0 2>/dev/null); do
        iommu_group_lines[$iommu_group]+="$(lspci -Dnns ${iommu_group_device##*/})$field_delimiter"
    done
done

# Loop through each IOMMU group's lines and print them out with the group number, indenting if necessary.
for iommu_group_key in $(echo "${!iommu_group_lines[@]}" | tr ' ' '\n' | sort -n); do
    if [ $iommu_group_key -lt 10 ]; then
        group_indent=" "
    else
        group_indent=""
    fi

    # Print out the group number with the appropriate group_indent.
    printf 'Group:\t%s%s' "$group_indent" "$iommu_group_key"

    # Loop through each line in the group and print it out.
    is_first_line="true"
    while IFS="$field_delimiter" read -ra device_lines; do
        for device_line in "${device_lines[@]}"; do
            # Extract the part of the lspci output that contains the device address.
            device_addr=$(echo "$device_line" | cut -d' ' -f1)

            # Use lspci to get the kernel driver in use for the device, and remove any leading or trailing whitespace.
            kernel_driver=$(lspci -k -s $device_addr | grep "Kernel driver in use" | cut -d ':' -f 2 | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            # Print out the line, indenting if necessary.
            if [ "$is_first_line" = "true" ]; then
                printf '  %s' "$device_line"
                is_first_line="false"
            else
                printf '\n\t    %s' "$device_line"
            fi

            # If there is a kernel driver in use for the device, print it out with a "Driver:" label.
            if ! [ -z "$kernel_driver" ]; then
                printf '   Driver: %s' "$kernel_driver"
            fi
        done
    done <<< "${iommu_group_lines[$iommu_group_key]}"
    printf '\n'
done