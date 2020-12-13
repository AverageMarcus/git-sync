#!/bin/bash

FAILED_MESSAGE=""

GITEA_TOKEN=${GITEA_TOKEN:?is not set}
GITHUB_TOKEN=${GITHUB_TOKEN:?is not set}
BITBUCKET_TOKEN=${BITBUCKET_TOKEN:?is not set}
GITLAB_TOKEN=${GITLAB_TOKEN:?is not set}

GITEA_BASE="https://averagemarcus:${GITEA_TOKEN}@git.cluster.fun/AverageMarcus/"
GITHUB_BASE="https://averagemarcus:${GITHUB_TOKEN}@github.com/AverageMarcus/"
BITBUCKET_BASE="https://averagemarcus:${BITBUCKET_TOKEN}@bitbucket.org/AverageMarcus/"
GITLAB_BASE="https://averagemarcus:${GITLAB_TOKEN}@gitlab.com/AverageMarcus/"

REPOS=$(curl -X GET "https://git.cluster.fun/api/v1/user/repos?page=1&limit=50&access_token=${GITEA_TOKEN}" -H  "accept: application/json" --silent | jq -r '.[] | select(.private!=true) | .name')

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
  curl -X POST -u averagemarcus:${BITBUCKET_TOKEN} -H "Content-Type: application/json" -d '{"scm": "git", "is_private": false,"project": {"key": "PROJ"}}' "https://api.bitbucket.org/2.0/repositories/averagemarcus/${1}"  --silent1> /dev/null
}

gitlabGetRepo() {
  curl -f "https://gitlab.com/api/v4/projects/averagemarcus/${1}?private_token=${GITLAB_TOKEN}" --silent 1> /dev/null
}
gitlabMakeRepo() {
  echo "Creating gitlab repo"
  curl -X POST --header "Content-Type: application/json" "https://gitlab.com/api/v4/projects?private_token=${GITLAB_TOKEN}" -d '{"name": "'${1}'", "visibility": "public"}' --silent 1> /dev/null
}

for REPO in ${REPOS}; do
  echo "Syncing ${REPO}"

  rm -rf ${REPO}
  mkdir -p ${REPO}
  cd ${REPO}
  git init 1> /dev/null

  BRANCH=$(getDefaultBranch ${REPO})

  git remote add gitea "${GITEA_BASE}${REPO}"
  git remote add github "${GITHUB_BASE}${REPO}"
  git remote add bitbucket "${BITBUCKET_BASE}${REPO}"
  git remote add gitlab "${GITLAB_BASE}${REPO}"

  failed() {
    printf "\n⚠️ Failed to sync ${REPO}\n\n"
    cd ..

    FAILED_MESSAGE="${FAILED_MESSAGE}\n⚠️ Failed to sync ${REPO}\n\n"
    continue
  }

  githubGetRepo ${REPO} || githubMakeRepo ${REPO}
  gitlabGetRepo ${REPO} || gitlabMakeRepo ${REPO}
  bitbucketGetRepo ${REPO} || bitbucketMakeRepo ${REPO}

  git pull --ff-only gitea ${BRANCH} 1> /dev/null || failed
  git pull --ff-only github ${BRANCH} 1> /dev/null || printf "\nℹ️ Unable to pull from GitHub\n\n"
  git pull --ff-only bitbucket ${BRANCH} 1> /dev/null || printf "\nℹ️ Unable to pull from BitBucket\n\n"
  git pull --ff-only gitlab ${BRANCH} 1> /dev/null || printf "\nℹ️ Unable to pull from Gitlab\n\n"

  git push gitea ${BRANCH} 1> /dev/null || failed
  git push github ${BRANCH} 1> /dev/null || failed
  git push bitbucket ${BRANCH} 1> /dev/null || failed
  git push gitlab ${BRANCH} 1> /dev/null || failed

  cd ..
  rm -rf ${REPO}
  printf "\n✅ Successfully synced ${REPO}\n\n"
done

if [ ! -z "${FAILED_MESSAGE}" ];
then
  printf ${FAILED_MESSAGE}
  exit 1
fi

exit 0
