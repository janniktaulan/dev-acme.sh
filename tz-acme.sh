#!/bin/bash
function upkeep() {
    #if ! command -v tz-acmesh >/dev/null 2>&1; then
    #    sudo mkdir -p /usr/local/bin
    #    if sudo mv /tmp/tz-acmesh /usr/local/bin/tz-acmesh; then
    #        sudo chmod +x /usr/local/bin/tz-acmesh
    #        sudo mkdir -p /etc/tz-acmesh
    #        echo "TZ-acmesh has been installed successfully. You can now run it using the command 'tz-acmesh' or 'sudo tz-acmesh'"
    #        exit
    #    else
    #        echo ""
    #        echo "Installation failed."
    #        exit 1
    #    fi
    #fi
    if ! command -v /root/.acme.sh/acme.sh >/dev/null 2>&1; then
        echo "acme.sh is not installed."
        read -n 1 -p "Do you want TZ-acmesh to try installing acme.sh? (y/n): " install_choice
        if [[ "$install_choice" == "y" ]]; then
            echo ""
            echo "Installing acme.sh..."
            curl https://get.acme.sh | sh -s email=my@example.com
        else
            echo ""
            echo "acme.sh is required to use TZ-acme.sh. If you need help installing acme.sh, please contact TRUSTZONE support at support@trustzone.com"
            exit 1
        fi
    fi
    mkdir -p /etc/tz-acmesh/scripts/
    
    if ! [ -e "/etc/tz-acmesh/scripts/.azure_credentials" ] ; then
        touch /etc/tz-acmesh/scripts/.azure_credentials
    fi
    if ! [ -e "/etc/tz-acmesh/scripts/.aws_credentials" ] ; then
        touch /etc/tz-acmesh/scripts/.aws_credentials
    fi

    if ! [ -e "/etc/tz-acmesh/scripts/.cloudflare_credentials" ] ; then
        touch /etc/tz-acmesh/scripts/.cloudflare_credentials
    fi

    if ! [ -e "/etc/tz-acmesh/scripts/.domeneshop_credentials" ] ; then
        touch /etc/tz-acmesh/scripts/.domeneshop_credentials
    fi

    if ! [ -e "/etc/tz-acmesh/scripts/.infoblox_credentials" ] ; then
        touch /etc/tz-acmesh/scripts/.infoblox_credentials
    fi
}
function start_prompt() {
    echo ""
    echo "Options:"
    echo "1. Order a new certificate"
    echo "2. Renewal Management"
    echo "3. Uninstall TZ-acmesh and acme.sh"
    echo "4. Exit"
    read -n 1 -p "Enter choice [1-4]: " initial_choice
    echo
    case $initial_choice in
        1)
            echo ""
            echo "You selected to order a new certificate."
            new_cert
            echo
            ;;
        2)
            renewal_management
            ;;
        3)
            echo ""
            echo "You selected to uninstall TZ-acmesh and acme.sh."
            read -n 1 -p "Are you sure you want to proceed? (y/n): " confirm_uninstall
            echo ""
            if [[ "$confirm_uninstall" == "y" ]]; then
                echo "Proceeding to uninstall..."
                uninstall
            else
                echo "Uninstallation cancelled."
                start_prompt
            fi
            ;;
        4)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
function read_credentials() {
    if test -f /etc/tz-acmesh/scripts/.user_credentials; then
    read -n 1 -p "Do you want to reuse saved EAB credentials? (y/n): " reuse_eab
    echo
        if [[ "$reuse_eab" == "y" ]]; then
            read -p "Please enter your domain: " domain
            echo
            return
        fi
    fi
    read -p "Please enter your EAB Key ID: " eab_kid
    read -p "Please enter your EAB HMAC Key: " eab_hmac
    read -p "Please enter your domain: " domain
    echo "export eab_kid=\"$eab_kid\"" > /etc/tz-acmesh/scripts/.user_credentials
    echo "export eab_hmac=\"$eab_hmac\"" >> /etc/tz-acmesh/scripts/.user_credentials
    chmod 600 /etc/tz-acmesh/scripts/.user_credentials
}
function new_cert() {
    # Prompt for validation method
    echo "How do you want to validate?"
    echo "1: HTTP or Pre-validation"
    echo "2: DNS validation"
    read -n 1 -p "Enter choice [1-3]: " validation_choice
    echo

    case $validation_choice in
        1)
            echo "MODE: Pre-validated"
            echo ""
            echo "Which web server are you using?"
            echo "1: Apache"
            echo "2: Nginx"
            read -n 1 -p "Enter choice [1-2]: " server_type
            case $server_type in
                1)
                    val_var="--apache"
                    echo ""
                    echo "Apache selected"
                    ;;
                2)
                    val_var="--nginx"
                    echo ""
                    echo "Nginx selected"
                    ;;
                *)
                    echo "Invalid choice, exiting."
                    exit 1
                    ;;
            esac
            read_credentials
            ;;
        2)
            echo "MODE: DNS"
            echo
            read_credentials
            dns_full
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    #reg var
    # Always source user credentials before using eab_kid and eab_hmac
    if [ -f /etc/tz-acmesh/scripts/.user_credentials ]; then
        . /etc/tz-acmesh/scripts/.user_credentials
    fi
    registration="--server https://emea.acme.atlas.globalsign.com/directory --email test123@test.com --insecure --force"

    #eab var
    eab="--eab-kid "${eab_kid:?}" --eab-hmac-key "${eab_hmac:?}""

    if /root/.acme.sh/acme.sh --register-account $registration $eab; then
        echo ""
        echo "Registration success."
    else
        echo ""
        echo "Something went wrong while trying to register your account."
        exit 1
    fi

    #domains
    if [[ "$domain" == "*."* ]]; then
        domain_non_wc=""${domain#*.}""
        domain_var="-d "${domain:?}" -d "${domain_non_wc:?}""
        domain_install="_."${domain#*.}""
    else
        domain_var="-d "${domain:?}""
        domain_install=""${domain:?}""
    fi

    ordering
    start_prompt
}
function ordering() {
    echo "acme.sh command: acme.sh --issue --server https://emea.acme.atlas.globalsign.com/directory $val_var -k 2048 $domain_var"
    if /root/.acme.sh/acme.sh --issue --server https://emea.acme.atlas.globalsign.com/directory $val_var --force -k 2048 $domain_var; then
        echo "Certificate received."
        read -p "Where should we install it?: " install_path
        echo ""
        read -p "What command would you like to use for reloading your webserver upon installation/renewals?: " reload_command
        echo ""
        if /root/.acme.sh/acme.sh --install-cert -d $domain_install --cert-file $install_path/$domain.crt --key-file $install_path/$domain.key --reloadcmd "$reload_command"; then
            echo ""
            echo "Certificate installed & automatic renewal enabled"
        else
            echo ""
            echo "Error while installing cert."
        fi
    else
        echo ""
        echo "There was a problem with the certificate request. Please check your credentials and domain validation."
        echo "You can also contact TRUSTZONE support at support@trustzone.com"
        exit
    fi
    echo ""
    echo "Your certificate is here: $path"
}
function renewal_management() {
    echo ""
    echo "Renewal management:"
    echo "1. List renewals"
    echo "2. Force renew all certificates"
    echo "3. Remove a renewal"
    echo "4. Back to main menu"
    read -n 1 -p "Enter choice [1-4]: " renewal_choice
    echo
    case $renewal_choice in
        1)
            echo ""
            echo "Listen renewals: "
            /root/.acme.sh/acme.sh --list
            renewal_management
            ;;
        2)
            echo ""
            echo "Forcefully running all renewals"
            /root/.acme.sh/acme.sh --renew-all --force
            renewal_management
            ;;
        3)
            echo ""
            echo "Listing renewals: "
            read -p "Please enter the domain of the renewal you wish to remove: " remove_renew
            /root/.acme.sh/acme.sh --remove --domain $remove_renew
            renewal_management
            ;;
        4)
            start_prompt
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
function uninstall() {
    echo ""
    echo "Welcome to the TZ-acmesh and acme.sh uninstaller."
    echo "This will uninstall TZ-acmesh and acme.sh from your system."
    read -n 1 -p "Are you sure you want to proceed? (y/n): " confirm_uninstall
    echo
    if [[ "$confirm_uninstall" == "y" ]]; then
        echo "Uninstalling TZ-acmesh and acme.sh..."
        if sudo rm -rf /etc/tz-acmesh/; then
            echo "removed /etc/tz-acmesh/ and all contents inside"
        else
            echo "Error deleting /etc/tz-acmesh/"
        fi
        /root/.acme.sh/acme.sh --uninstall
        if command -v /root/.acme.sh/acme.sh >/dev/null 2>&1; then
            echo "Uninstallation of acme.sh failed. Please remove manually."
        else
            echo "acme.sh have been uninstalled successfully."
        fi
        if command -v tz-acmesh >/dev/null 2>&1; then
            echo "Uninstallation of TZ-acmesh failed. Please remove manually."
        else
            echo "TZ-acmesh have been uninstalled successfully."
        fi
        exit
    else
        echo "Uninstallation cancelled."
        exit
    fi
}
function dns_full() {
    echo ""
    echo "Which DNS provider would you like to use?"
    echo "1. Azure DNS"
    echo "2. AWS/Route 53"
    echo "3. Cloudflare"
    echo "4. Domeneshop"
    echo "5. Google DNS (NOT WORKING ATM)"
    read -n 1 -p "Enter choice [1-5]: " renewal_choice
    echo ""
    case $renewal_choice in
        1)
            val_var="--dns dns_azure"
            if grep -q "export AZURE" "/etc/tz-bot/scripts/.azure_credentials"; then
                read -n 1 -p "Do you want to reuse saved Azure credentials? (y/n): " reuse_azure
                echo ""
                if [[ "$reuse_azure" == "y" ]]; then
                    . /etc/tz-bot/scripts/.azure_credentials
                    return
                fi
            fi
            read -p "Please enter your Azure Client ID: " azure_client_id
            read -p "Please enter your Azure Client Secret: " azure_client_secret
            read -p "Please enter your Azure Tenant ID: " azure_tenant_id
            read -p "Please enter your Azure Subscription ID: " azure_subscription_id
            echo "export AZURE_CLIENT_ID=\"$azure_client_id\"" > /etc/tz-bot/scripts/.azure_credentials
            echo "export AZURE_CLIENT_SECRET=\"$azure_client_secret\"" >> /etc/tz-bot/scripts/.azure_credentials
            echo "export AZURE_TENANT_ID=\"$azure_tenant_id\"" >> /etc/tz-bot/scripts/.azure_credentials
            echo "export AZURE_SUBSCRIPTION_ID=\"$azure_subscription_id\"" >> /etc/tz-bot/scripts/.azure_credentials
            chmod 600 /etc/tz-bot/scripts/.azure_credentials
            . /etc/tz-bot/scripts/.azure_credentials
            ;;
        2)
            val_var="--dns dns_aws"
            if grep -q "export AWS" "/etc/tz-bot/scripts/.aws_credentials"; then
                read -n 1 -p "Do you want to reuse saved AWS credentials? (y/n): " reuse_aws
                echo ""
                if [[ "$reuse_aws" == "y" ]]; then
                    . /etc/tz-bot/scripts/.aws_credentials
                    return
                fi
            fi
            read -p "Please enter your AWS Access Key ID: " aws_access_key_id
            read -p "Please enter your AWS Secret Access Key: " aws_secret_access_key
            echo "export AWS_ACCESS_KEY_ID=\"$aws_access_key_id\"" > /etc/tz-bot/scripts/.aws_credentials
            echo "export AWS_SECRET_ACCESS_KEY=\"$aws_secret_access_key\"" >> /etc/tz-bot/scripts/.aws_credentials
            chmod 600 /etc/tz-bot/scripts/.aws_credentials
            . /etc/tz-bot/scripts/.aws_credentials
            ;;
        3)
            val_var="--dns dns_cf"
            if grep -q "export CLOUDFLARE" "/etc/tz-bot/scripts/.cloudflare_credentials"; then
                read -n 1 -p "Do you want to reuse saved Cloudflare credentials? (y/n): " reuse_cloudflare
                echo ""
                if [[ "$reuse_cloudflare" == "y" ]]; then
                    . /etc/tz-bot/scripts/.cloudflare_credentials
                    return
                fi
            fi
            echo ""
            echo "Options:"
            echo "1. Use an account-owned token (Recommended - more safe)"
            echo "2. Use a global API key (Not-recommended - less safe)"
            read -n 1 -p "Enter choice [1-4]: " initial_choice
            echo
            case $initial_choice in
                1)
                    read -p "Please enter your Cloudflare Token: " cf_token
                    read -p "Please enter your Cloudflare Account ID: " cf_account_id
                    echo "export CF_Token=\"$cf_token\"" > /etc/tz-bot/scripts/.cloudflare_credentials
                    echo "export CF_Account_ID=\"$cf_account_id\"" >> /etc/tz-bot/scripts/.cloudflare_credentials
                    chmod 600 /etc/tz-bot/scripts/.cloudflare_credentials
                    . /etc/tz-bot/scripts/.cloudflare_credentials
                    ;;
                2)
                    read -p "Please enter your Cloudflare account email: " cf_email
                    read -p "Please enter your Cloudflare API Key: " cf_key
                    echo "export CF_Email=\"$cf_email\"" > /etc/tz-bot/scripts/.cloudflare_credentials
                    echo "export CF_Key=\"$cf_key\"" >> /etc/tz-bot/scripts/.cloudflare_credentials
                    chmod 600 /etc/tz-bot/scripts/.cloudflare_credentials
                    . /etc/tz-bot/scripts/.cloudflare_credentials
                    ;;
                *)
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        4)
            val_var="--dns dns_domeneshop"
            if grep -q "export DOMENESHOP" "/etc/tz-bot/scripts/.domeneshop_credentials"; then
                read -n 1 -p "Do you want to reuse saved Domeneshop credentials? (y/n): " reuse_domeneshop
                echo ""
                if [[ "$reuse_domeneshop" == "y" ]]; then
                    . /etc/tz-bot/scripts/.domeneshop_credentials
                    return
                fi
            fi
            read -p "Please enter your Domeneshop API Token: " domeneshop_token
            read -p "Please enter your Domeneshop API Secret: " domeneshop_secret
            echo "export DOMENESHOP_Token=\"$domeneshop_token\"" > /etc/tz-bot/scripts/.domeneshop_credentials
            echo "export DOMENESHOP_Secret=\"$domeneshop_secret\"" >> /etc/tz-bot/scripts/.domeneshop_credentials
            chmod 600 /etc/tz-bot/scripts/.domeneshop_credentials
            . /etc/tz-bot/scripts/.domeneshop_credentials
            ;;
        5)
            val_var="--dns dns_googledomains"
            #export GOOGLEDOMAINS_ACCESS_TOKEN="<generated-access-token>"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
echo "Welcome to TZ-Bot V0.1 (ACME.SH)"
upkeep
start_prompt