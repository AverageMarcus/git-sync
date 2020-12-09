#!/bin/bash

EXIT_CODE=0
FAILED_MESSAGE=""

GITEA_TOKEN=${GITEA_TOKEN:?is not set}
GITHUB_TOKEN=${GITHUB_TOKEN:?is not set}
BITBUCKET_TOKEN=${BITBUCKET_TOKEN:?is not set}
GITLAB_TOKEN=${GITLAB_TOKEN:?is not set}

GITEA_BASE="https://averagemarcus:${GITEA_TOKEN}@git.cluster.fun/AverageMarcus/"
GITHUB_BASE="https://averagemarcus:${GITHUB_TOKEN}@github.com/AverageMarcus/"
BITBUCKET_BASE="https://bitbucket.org/AverageMarcus/"
GITLAB_BASE="https://gitlab.com/AverageMarcus/"

REPOS=$(curl -X GET "https://git.cluster.fun/api/v1/user/repos?page=1&limit=50&access_token=${GITEA_TOKEN}" -H  "accept: application/json" --silent | jq -r '.[] | select(.private!=true) | .name')

getDefaultBranch() {
  curl -X GET "https://git.cluster.fun/api/v1/repos/AverageMarcus/${1}?access_token=${GITEA_TOKEN}" -H  "accept: application/json" --silent | jq -r '.default_branch'
}

githubGetRepo() {
  curl -f -u averagemarcus:${GITHUB_TOKEN} "https://api.github.com/repos/averagemarcus/${1}" -H  "accept: application/vnd.github.v3+json" --silent
}
githubMakeRepo() {
  curl -X POST -f -u averagemarcus:${GITHUB_TOKEN} "https://api.github.com/user/repos" -H  "accept: application/vnd.github.v3+json" -d '{"name": "'${1}'", "private": false, "auto_init": false, "delete_branch_on_merge": true}' --silent
}

bitbucketGetRepo() {
  curl -f "https://api.bitbucket.org/2.0/repositories/averagemarcus/${1}"
}
bitbucketMakeRepo() {
  curl -X POST -H "Content-Type: application/json" -d '{"scm": "git", "is_private": false,"project": {"key": "PROJ"}}' "https://api.bitbucket.org/2.0/repositories/averagemarcus/${0}"
}

gitlabGetRepo() {
  curl -f --silent -u averagemarcus:${BITBUCKET_TOKEN} "https://gitlab.com/api/v4/projects/averagemarcus/${1}?access_token=${GITLAB_TOKEN}"
}
gitlabMakeRepo() {
curl -X POST -u averagemarcus:${BITBUCKET_TOKEN} "https://gitlab.com/api/v4/projects?access_token=${GITLAB_TOKEN}" -d '{"name": "'${1}'", "visibility": "public"}' --silent
}

for REPO in ${REPOS}; do
  echo "Syncing ${REPO}"

  rm -rf ${REPO}
  mkdir -p ${REPO}
  cd ${REPO}
  git init

  BRANCH=$(getDefaultBranch ${REPO})

  git remote add gitea "${GITEA_BASE}${REPO}"
  git remote add github "${GITHUB_BASE}${REPO}"
  git remote add bitbucket "${BITBUCKET_BASE}${REPO}"
  git remote add gitlab "${GITLAB_BASE}${REPO}"

  failed() {
    EXIT_CODE=1
    printf "\n⚠️ Failed to sync ${REPO}\n\n"
    cd ..

    FAILED_MESSAGE="${FAILED_MESSAGE}\n⚠️ Failed to sync ${REPO}\n\n"
    continue
  }

  githubGetRepo ${REPO} || githubMakeRepo ${REPO}
  gitlabGetRepo ${REPO} || gitlabMakeRepo ${REPO}
  bitbucketGetRepo ${REPO} || bitbucketMakeRepo ${REPO}

  git pull --ff-only gitea ${BRANCH} || failed
  git pull --ff-only github ${BRANCH} || printf "\nℹ️ Unable to pull from GitHub\n\n"
  git pull --ff-only bitbucket ${BRANCH} || printf "\nℹ️ Unable to pull from BitBucket\n\n"
  git pull --ff-only gitlab ${BRANCH} || printf "\nℹ️ Unable to pull from Gitlab\n\n"

  git push gitea ${BRANCH} || failed
  git push github ${BRANCH} || failed
  git push bitbucket ${BRANCH} || failed
  git push gitlab ${BRANCH} || failed

  cd ..
  rm -rf ${REPO}
  printf "\n✅ Successfully synced ${REPO}\n\n"
done

echo ${FAILED_MESSAGE}
exit ${EXIT_CODE}
