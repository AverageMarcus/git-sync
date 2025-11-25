#!/bin/bash

FAILED_MESSAGE=""

GITEA_TOKEN=${GITEA_TOKEN:?is not set}
GITHUB_TOKEN=${GITHUB_TOKEN:?is not set}
BITBUCKET_TOKEN=${BITBUCKET_TOKEN:?is not set}
GITLAB_TOKEN=${GITLAB_TOKEN:?is not set}
CODEBERG_TOKEN=${CODEBERG_TOKEN:?is not set}

GITEA_BASE="https://averagemarcus:${GITEA_TOKEN}@git.cluster.fun/AverageMarcus/"
GITHUB_BASE="https://averagemarcus:${GITHUB_TOKEN}@github.com/AverageMarcus/"
BITBUCKET_BASE="https://averagemarcus:${BITBUCKET_TOKEN}@bitbucket.org/AverageMarcus/"
GITLAB_BASE="https://averagemarcus:${GITLAB_TOKEN}@gitlab.com/AverageMarcus/"
CODEBERG_BASE="https://averagemarcus:${CODEBERG_TOKEN}@codeberg.org/AverageMarcus/"

REPOS=""
PAGE=1
while :
do
  REPO_PAGE=$(curl -X GET "https://git.cluster.fun/api/v1/user/repos?page=${PAGE}&limit=50&access_token=${GITEA_TOKEN}" -H  "accept: application/json" --silent | jq -r '.[] | select(.private!=true) | .name')
  if [[ "${REPO_PAGE}" == "" ]]; then
    break
  fi
  REPOS="${REPOS} ${REPO_PAGE}"
  PAGE=$((PAGE + 1))
done

getDefaultBranch() {
  curl -X GET "https://git.cluster.fun/api/v1/repos/AverageMarcus/${1}?access_token=${GITEA_TOKEN}" -H  "accept: application/json" --silent | jq -r '.default_branch'
}

githubGetRepo() {
  curl -f -u averagemarcus:${GITHUB_TOKEN} "https://api.github.com/repos/averagemarcus/${1}" -H  "accept: application/vnd.github.v3+json" --silent 1> /dev/null
}
githubMakeRepo() {
  echo "Creating github repo"
  curl -X POST -f -u averagemarcus:${GITHUB_TOKEN} "https://api.github.com/user/repos" -H  "accept: application/vnd.github.v3+json" -d '{"name": "'${1}'", "private": false, "auto_init": false, "delete_branch_on_merge": true}' --silent 1> /dev/null
}

bitbucketGetRepo() {
  curl -f -u averagemarcus:${BITBUCKET_TOKEN} "https://api.bitbucket.org/2.0/repositories/averagemarcus/${1}" --silent 1> /dev/null
}
bitbucketMakeRepo() {
  echo "Creating bitbucket repo"
  curl -X POST -u averagemarcus:${BITBUCKET_TOKEN} -H "Content-Type: application/json" -d '{"scm": "git", "is_private": false,"project": {"key": "PROJ"}}' "https://api.bitbucket.org/2.0/repositories/averagemarcus/${1}"  --silent 1> /dev/null
}

gitlabGetRepo() {
  curl -f "https://gitlab.com/api/v4/projects/averagemarcus%2F$(echo ${1} |tr "." "-")?private_token=${GITLAB_TOKEN}" --silent 1> /dev/null
}
gitlabMakeRepo() {
  echo "Creating gitlab repo"
  curl -X POST --header "Content-Type: application/json" "https://gitlab.com/api/v4/projects?private_token=${GITLAB_TOKEN}" -d '{"name": "'${1}'", "visibility": "public"}' --silent 1> /dev/null

  PROJECT_ID=$(curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/averagemarcus%2F${1}" | jq .id -r)
  curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" --header "Content-Type: application/json" "https://gitlab.com/api/v4/projects/${PROJECT_ID}/protected_branches?name=master&push_access_level=40&merge_access_level=40&allow_force_push=true"
  curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" --header "Content-Type: application/json" "https://gitlab.com/api/v4/projects/${PROJECT_ID}/protected_branches?name=main&push_access_level=40&merge_access_level=40&allow_force_push=true"
}

codebergGetRepo() {
  curl -f -X GET "https://codeberg.org/api/v1/repos/averagemarcus/${1}?access_token=${CODEBERG_TOKEN}" -H 'accept: application/json' --silent 1> /dev/null
}
codebergMakeRepo() {
  echo "Creating codeberg repo"
  curl -X POST "https://codeberg.org/api/v1/user/repos?access_token=${CODEBERG_TOKEN}" \
    -H "Content-Type: application/json" -H 'accept: application/json' \
    -d '{"auto_init": false, "private": false, "name": "'${1}'"}' --silent 1> /dev/null
}

for REPO in ${REPOS}; do
  printf "\n🔄 Syncing ${REPO}\n\n"

  rm -rf ${REPO}

  git clone "${GITEA_BASE}${REPO}" ${REPO}
  cd ${REPO}

  BRANCH=$(getDefaultBranch ${REPO})

  git remote add gitea "${GITEA_BASE}${REPO}" 1> /dev/null
  git remote add github "${GITHUB_BASE}${REPO}" 1> /dev/null
  git remote add bitbucket "${BITBUCKET_BASE}${REPO}" 1> /dev/null
  git remote add gitlab "${GITLAB_BASE}$(echo ${REPO} |tr "." "-")" 1> /dev/null
  # git remote add codeberg "${CODEBERG_BASE}${REPO}" 1> /dev/null

  failed() {
    printf "\n⚠️ Failed to sync ${REPO} to ${1}\n\n"
    cd ..

    FAILED_MESSAGE="${FAILED_MESSAGE}\n⚠️ Failed to sync ${REPO} to ${1}\n\n"
  }

  githubGetRepo ${REPO} || githubMakeRepo ${REPO}
  gitlabGetRepo ${REPO} || gitlabMakeRepo ${REPO}
  bitbucketGetRepo ${REPO} || bitbucketMakeRepo ${REPO}
  # codebergGetRepo ${REPO} || codebergMakeRepo ${REPO}

  git pull --ff-only gitea ${BRANCH} 1> /dev/null || { failed; continue; }
  git pull --ff-only github ${BRANCH} 1> /dev/null || printf "\nℹ️ Unable to pull from GitHub\n\n"
  git pull --ff-only bitbucket ${BRANCH} 1> /dev/null || printf "\nℹ️ Unable to pull from BitBucket\n\n"
  git pull --ff-only gitlab ${BRANCH} 1> /dev/null || printf "\nℹ️ Unable to pull from Gitlab\n\n"
  # git pull --ff-only codeberg ${BRANCH} 1> /dev/null || printf "\nℹ️ Unable to pull from Codeberg\n\n"

  git push --follow-tags --set-upstream gitea ${BRANCH} 1> /dev/null || { failed "gitea"; }
  git push -f --follow-tags --set-upstream github ${BRANCH} 1> /dev/null || { failed "github"; }
  git push -f --follow-tags --set-upstream bitbucket ${BRANCH} 1> /dev/null || { failed "bitbucket"; }
  git push -f --follow-tags --set-upstream gitlab ${BRANCH} 1> /dev/null || { failed "gitlab"; }
  # git push -f --follow-tags --set-upstream codeberg ${BRANCH} 1> /dev/null || { failed "codeberg"; }

  cd ..
  rm -rf ${REPO}
  printf "\n✅ Successfully synced ${REPO}\n\n"
done

if [ -n "${FAILED_MESSAGE}" ];
then
  printf "\n\n--------\n\n"
  echo "Failed!"
  printf "${FAILED_MESSAGE}"
  exit 1
else
  echo "All completed successfully!"
  exit 0
fi

