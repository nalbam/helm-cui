#!/bin/bash

command -v fzf > /dev/null && FZF=true
command -v tput > /dev/null && TPUT=true

_echo() {
    if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
        echo -e "${L_PAD}$(tput setaf $2)$1$(tput sgr0)"
    else
        echo -e "${L_PAD}$1"
    fi
}

_read() {
    echo
    if [ "${3}" == "S" ]; then
        if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
            read -s -p "${L_PAD}$(tput setaf $2)$1$(tput sgr0)" ANSWER
        else
            read -s -p "${L_PAD}$1" ANSWER
        fi
    else
        if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
            read -p "${L_PAD}$(tput setaf $2)$1$(tput sgr0)" ANSWER
        else
            read -p "${L_PAD}$1" ANSWER
        fi
    fi
}

_replace() {
    if [ "${OS_NAME}" == "darwin" ]; then
        sed -i "" -e "$1" $2
    else
        sed -i -e "$1" $2
    fi
}

_result() {
    echo
    _echo "# $@" 4
}

_command() {
    echo
    _echo "$ $@" 3
}

_success() {
    echo
    _echo "+ $@" 2
    _exit 0
}

_error() {
    echo
    _echo "- $@" 1
    _exit 1
}

_exit() {
    echo
    exit $1
}

question() {
    _read "${1:-"Enter your choice : "}" 6

    if [ ! -z ${2} ]; then
        if ! [[ ${ANSWER} =~ ${2} ]]; then
            ANSWER=
        fi
    fi
}

password() {
    _read "${1:-"Enter your password : "}" 6 S
}

print_list() {
    IDX=0
    while read VAL; do
        IDX=$(( ${IDX} + 1 ))
        printf "%2s. %s\n" "${IDX}" "${VAL}"
    done < ${LIST}
}

select_one() {
    OPT=$1

    SELECTED=

    CNT=$(cat ${LIST} | wc -l | xargs)
    if [ "x${CNT}" == "x0" ]; then
        return
    fi

    if [ "${OPT}" != "" ] && [ "x${CNT}" == "x1" ]; then
        SELECTED="$(cat ${LIST} | xargs)"
    else
        echo

        print_list

        if [ "${CNT}" != "1" ]; then
            CNT="1-${CNT}"
        fi

        _read "Please select one. (${CNT}) : " 6

        if [ -z ${ANSWER} ]; then
            return
        fi
        TEST='^[0-9]+$'
        if ! [[ ${ANSWER} =~ ${TEST} ]]; then
            return
        fi
        SELECTED=$(sed -n ${ANSWER}p ${LIST})
    fi
}

progress() {
    if [ "$1" == "start" ]; then
        printf '%2s'
    elif [ "$1" == "end" ]; then
        printf '.\n'
    else
        printf '.'
        sleep 2
    fi
}

waiting() {
    SEC=${1:-2}

    echo
    progress start

    IDX=0
    while true; do
        if [ "${IDX}" == "${SEC}" ]; then
            break
        fi
        IDX=$(( ${IDX} + 1 ))
        progress ${IDX}
    done

    progress end
    echo
}

# get_az_list() {
#     if [ -z ${AZ_LIST} ]; then
#         AZ_LIST="$(aws ec2 describe-availability-zones | jq -r '.AvailabilityZones[].ZoneName' | head -3 | tr -s '\r\n' ',' | sed 's/.$//')"
#     fi
# }

# get_master_zones() {
#     if [ "${master_count}" == "1" ]; then
#         master_zones=$(echo "${AZ_LIST}" | cut -d',' -f1)
#     else
#         master_zones="${AZ_LIST}"
#     fi
# }

# get_node_zones() {
#     if [ "${node_count}" == "1" ]; then
#         zones=$(echo "${AZ_LIST}" | cut -d',' -f1)
#     else
#         zones="${AZ_LIST}"
#     fi
# }

get_template() {
    __FROM=${SHELL_DIR}/${1}
    __DIST=${2}

    mkdir -p ${SHELL_DIR}/build/${THIS_NAME}
    rm -rf ${__DIST}

    if [ -f ${__FROM} ]; then
        cat ${__FROM} > ${__DIST}
    else
        curl -sL https://raw.githubusercontent.com/${THIS_REPO}/${THIS_NAME}/master/${1} > ${__DIST}
    fi
    if [ ! -f ${__DIST} ]; then
        _error "Template does not exists. [${1}]"
    fi
}

update_tools() {
    curl -sL toast.sh/tools | bash

    _success "Please restart!"
}

update_self() {
    pushd ${SHELL_DIR}
    git pull
    popd

    _success "Please restart!"
}

logo() {
    if [ "${TPUT}" != "" ]; then
        tput clear
        tput setaf 3
    fi

    cat ${SHELL_DIR}/templates/logo-${THIS_NAME}.txt
    echo

    if [ "${TPUT}" != "" ]; then
        tput sgr0
    fi
}

config_load() {
    COUNT=$(kubectl get pod -n kube-system | wc -l | xargs)

    if [ "x${COUNT}" == "x0" ]; then
        _error "Unable to connect to the cluster."
    fi

    COUNT=$(kubectl get secret -n default | grep ${THIS_NAME}-config  | wc -l | xargs)

    if [ "x${COUNT}" != "x0" ]; then
        mkdir -p ${SHELL_DIR}/build/${CLUSTER_NAME}

        CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/config.sh

        kubectl get secret ${THIS_NAME}-config -n default -o json | \
            jq -r '.data.text' | base64 --decode > ${CONFIG}

        _command "load ${THIS_NAME}-config"
        cat ${CONFIG}

        . ${CONFIG}
    fi
}

config_save() {
    if [ "${CONFIG_SAVE}" == "" ]; then
        return
    fi

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/config.sh

    echo "# ${THIS_NAME} config" > ${CONFIG}
    echo "CLUSTER_NAME=${CLUSTER_NAME}" >> ${CONFIG}
    echo "ROOT_DOMAIN=${ROOT_DOMAIN}" >> ${CONFIG}
    echo "BASE_DOMAIN=${BASE_DOMAIN}" >> ${CONFIG}
    echo "EFS_ID=${EFS_ID}" >> ${CONFIG}
    echo "ISTIO=${ISTIO}" >> ${CONFIG}
    echo "ISTIO_DOMAIN=${ISTIO_DOMAIN}" >> ${CONFIG}

    _command "save ${THIS_NAME}-config"
    cat ${CONFIG}

    ENCODED=${SHELL_DIR}/build/${CLUSTER_NAME}/config.txt

    if [ "${OS_NAME}" == "darwin" ]; then
        cat ${CONFIG} | base64 > ${ENCODED}
    else
        cat ${CONFIG} | base64 -w 0 > ${ENCODED}
    fi

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/secret-config.yaml
    get_template templates/secret-config.yaml ${CONFIG}

    _replace "s/REPLACE-ME/${THIS_NAME}-config/" ${CONFIG}

    sed "s/^/    /" ${ENCODED} >> ${CONFIG}

    _command "kubectl apply -f ${CONFIG} -n default"
    kubectl apply -f ${CONFIG} -n default

    CONFIG_SAVE=
}

variables_domain() {
    __KEY=${1}
    __VAL=$(kubectl get ing --all-namespaces | grep devops | grep ${__KEY} | awk '{print $3}' | cut -d',' -f1)

    echo "@Field" >> ${CONFIG}
    echo "def ${__KEY} = \"${__VAL}\"" >> ${CONFIG}
}

variables_show() {
    COUNT=$(kubectl get secret -n default | grep groovy-variables | wc -l | xargs)
    if [ "x${COUNT}" == "x0" ]; then
        _result "No have groovy-variables."
        return
    fi

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/variables.groovy

    _command "kubectl get secret groovy-variables -n default"
    kubectl get secret groovy-variables -n default -o json | jq -r .data.groovy | base64 --decode > ${CONFIG}

    echo
    cat ${CONFIG} | grep "def "
}

variables_edit() {
    COUNT=$(kubectl get secret -n default | grep groovy-variables | wc -l | xargs)
    if [ "x${COUNT}" == "x0" ]; then
        _result "No have groovy-variables."
        return
    fi

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/variables.groovy

    _command "kubectl get secret groovy-variables -n default"
    kubectl get secret groovy-variables -n default -o json | jq -r .data.groovy | base64 --decode > ${CONFIG}

    LIST=${SHELL_DIR}/build/${CLUSTER_NAME}/variables-list

    cat ${CONFIG} | grep 'def ' | cut -d' ' -f2 > ${LIST}

    # select
    select_one

    if [ "${SELECTED}" == "" ]; then
        return
    fi

    DEFAULT="$(cat ${CONFIG} | grep 'def ' | grep ${SELECTED} | cut -d'"' -f2)"

    question "${SELECTED} = [${DEFAULT}] : "
    if [ "${ANSWER}" == "" ]; then
        ANSWER=${DEFAULT}
    fi

    _replace "s/def ${SELECTED} = .*/def ${SELECTED} = \"${ANSWER}\"/" ${CONFIG}

    echo
    cat ${CONFIG} | grep "def "

    variables_save
}

variables_auto() {
    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/variables.groovy

    echo "#!/usr/bin/groovy" > ${CONFIG}
    echo "import groovy.transform.Field" >> ${CONFIG}

    COUNT=$(kubectl get ing --all-namespaces | grep devops | wc -l | xargs)
    if [ "x${COUNT}" == "x0" ]; then
        echo "@Field" >> ${CONFIG}
        echo "def cluster = \"${CLUSTER_NAME}\"" >> ${CONFIG}
    else
        echo "@Field" >> ${CONFIG}
        echo "def cluster = \"devops\"" >> ${CONFIG}
    fi

    echo "@Field" >> ${CONFIG}
    echo "def root_domain = \"${ROOT_DOMAIN}\"" >> ${CONFIG}

    echo "@Field" >> ${CONFIG}
    echo "def base_domain = \"${BASE_DOMAIN}\"" >> ${CONFIG}

    if [ "x${COUNT}" != "x0" ]; then
        variables_domain "chartmuseum"
        variables_domain "harbor"
        variables_domain "jenkins"
        variables_domain "nexus"
        variables_domain "registry"
        variables_domain "sonarqube"
    fi

    echo "@Field" >> ${CONFIG}
    echo "def slack_token = \"\"" >> ${CONFIG}

    echo "return this" >> ${CONFIG}

    echo
    cat ${CONFIG} | grep "def "

    variables_save
}

variables_save() {
    ENCODED=${SHELL_DIR}/build/${CLUSTER_NAME}/variables.txt

    if [ "${OS_NAME}" == "darwin" ]; then
        cat ${CONFIG} | base64 > ${ENCODED}
    else
        cat ${CONFIG} | base64 -w 0 > ${ENCODED}
    fi

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/secret-groovy.yaml
    get_template templates/secret-groovy.yaml ${CONFIG}

    _replace "s/REPLACE-ME/groovy-variables/" ${CONFIG}

    sed "s/^/    /" ${ENCODED} >> ${CONFIG}

    _command "kubectl apply -f ${CONFIG} -n default"
    kubectl apply -f ${CONFIG} -n default
}
