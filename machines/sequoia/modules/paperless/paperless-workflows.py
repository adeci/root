"""Run by `paperless-manage shell`."""

import os

from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from documents.models import Tag, Workflow, WorkflowAction, WorkflowTrigger

Action = WorkflowAction.WorkflowActionType
Field = WorkflowAction.AISuggestionField
Trigger = WorkflowTrigger.WorkflowTriggerType

AI_WORKFLOW = "AI classification"


def plain_tag(name: str, owner: User, *, inbox: bool = False) -> Tag:
    """A tag that only workflows and people assign, never automatic matching."""
    tag, _ = Tag.objects.update_or_create(
        name=name,
        owner=owner,
        defaults={"is_inbox_tag": inbox, "matching_algorithm": Tag.MATCH_NONE},
    )
    return tag


def declare_workflow(
    name: str, order: int, actions: list[WorkflowAction], retag: Tag | None = None
) -> None:
    """Runs `actions` on new documents, and on documents tagged `retag` when given."""
    workflow, _ = Workflow.objects.update_or_create(
        name=name, defaults={"order": order, "enabled": True}
    )
    workflow.triggers.all().delete()
    workflow.actions.all().delete()

    triggers = [WorkflowTrigger.objects.create(type=Trigger.DOCUMENT_ADDED)]
    if retag is not None:
        tagged = WorkflowTrigger.objects.create(type=Trigger.DOCUMENT_UPDATED)
        tagged.filter_has_tags.set([retag])
        triggers.append(tagged)
    workflow.triggers.set(triggers)
    workflow.actions.set(actions)


def remove_workflow(name: str) -> None:
    """Deletes a workflow along with its triggers and actions."""
    for workflow in Workflow.objects.filter(name=name):
        workflow.triggers.all().delete()
        workflow.actions.all().delete()
        workflow.delete()


def declare_ai_workflow(classify: Tag) -> None:
    """Lets the AI fill in a new or Classify-tagged document, then removes the tag."""
    suggest = WorkflowAction.objects.create(
        type=Action.APPLY_AI_SUGGESTIONS,
        order=0,
        ai_suggestion_fields=[
            Field.TITLE,
            Field.TAGS,
            Field.CORRESPONDENT,
            Field.DOCUMENT_TYPE,
            Field.CREATED,
        ],
        ai_create_missing=True,
        # Consumption always fills in a title and date, so the AI has to overwrite them.
        ai_overwrite_existing=True,
    )
    done = WorkflowAction.objects.create(type=Action.REMOVAL, order=1)
    done.remove_tags.set([classify])
    declare_workflow(AI_WORKFLOW, 1, [suggest, done], retag=classify)


def main() -> None:
    owner = User.objects.get(username=os.environ["PAPERLESS_ADMIN_USER"])
    if not Tag.objects.filter(is_inbox_tag=True).exists():
        plain_tag("Inbox", owner, inbox=True)

    # Ordered first so the owner is saved before the AI runs; the AI only reuses tags, types and correspondents that owner can see.
    assign = WorkflowAction.objects.create(type=Action.ASSIGNMENT, assign_owner=owner)
    assign.assign_tags.set(Tag.objects.filter(is_inbox_tag=True))

    if settings.AI_ENABLED:
        classify = plain_tag("Classify", owner)
        declare_workflow("Inbox and owner", 0, [assign], retag=classify)
        declare_ai_workflow(classify)
    else:
        declare_workflow("Inbox and owner", 0, [assign])
        remove_workflow(AI_WORKFLOW)


with transaction.atomic():
    main()
