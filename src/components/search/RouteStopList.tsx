import {
  DndContext,
  type DragEndEvent,
  type DraggableAttributes,
  KeyboardSensor,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import {
  MAX_ROUTE_STOPS,
  type RouteStopRow,
  routeEndPlace,
  routeStartPlace,
  useRouteStore,
} from '../../stores/routeStore'
import { PlaceInput } from './PlaceInput'

function rowLabel(index: number): string {
  return String.fromCharCode(65 + index)
}

function DragHandle({
  attributes,
  listeners,
}: {
  attributes: DraggableAttributes
  listeners: Record<string, unknown> | undefined
}) {
  return (
    <button
      type="button"
      className="mt-0.5 flex h-[38px] w-7 shrink-0 cursor-grab touch-none items-center justify-center rounded-lg border border-transparent text-slate-400 hover:bg-slate-100 hover:text-slate-600 active:cursor-grabbing dark:hover:bg-slate-800 dark:hover:text-slate-300"
      title="Drag to reorder"
      aria-label="Drag to reorder stop"
      {...attributes}
      {...((listeners ?? {}) as Record<string, unknown>)}
    >
      <svg
        width={14}
        height={18}
        viewBox="0 0 14 18"
        fill="currentColor"
        aria-hidden
      >
        <circle cx="4" cy="4" r="1.6" />
        <circle cx="10" cy="4" r="1.6" />
        <circle cx="4" cy="9" r="1.6" />
        <circle cx="10" cy="9" r="1.6" />
        <circle cx="4" cy="14" r="1.6" />
        <circle cx="10" cy="14" r="1.6" />
      </svg>
    </button>
  )
}

function SortableStopRow({
  row,
  index,
  total,
  canPlan,
  onPlan,
  canSwap,
}: {
  row: RouteStopRow
  index: number
  total: number
  canPlan: boolean
  onPlan: () => void
  canSwap: boolean
}) {
  const setStopPlaceAt = useRouteStore((s) => s.setStopPlaceAt)
  const removeStopAt = useRouteStore((s) => s.removeStopAt)
  const swapRouteEndpoints = useRouteStore((s) => s.swapRouteEndpoints)

  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: row.id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  const isFirst = index === 0
  const isLast = index === total - 1
  const showRemove = !isFirst && !isLast

  const placeholder = isFirst
    ? 'Choose starting point'
    : isLast
      ? 'Choose destination'
      : 'Add a stop'

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`flex gap-1.5 ${isDragging ? 'z-10 opacity-90' : ''}`}
    >
      <DragHandle attributes={attributes} listeners={listeners} />
      <div
        className="flex h-[38px] w-6 shrink-0 items-center justify-center text-xs font-bold text-slate-500 dark:text-slate-400"
        aria-hidden
      >
        {rowLabel(index)}
      </div>
      <div className="min-w-0 flex-1">
        <PlaceInput
          placeholder={placeholder}
          value={row.place}
          onChange={(p) => setStopPlaceAt(index, p)}
          onEnter={() => {
            if (canPlan) void onPlan()
          }}
          onEscape={() => {
            if (isLast) setStopPlaceAt(index, null)
            else if (showRemove) removeStopAt(index)
          }}
          showMyLocationButton={isFirst}
          trailingAction={
            isLast ? (
              <button
                type="button"
                onClick={() => swapRouteEndpoints()}
                disabled={!canSwap}
                title="Reverse stops (swap start and end)"
                aria-label="Reverse stops"
                className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-lg border border-slate-200 bg-white/95 text-slate-600 shadow-sm transition hover:border-blue-400 hover:bg-slate-50 hover:text-blue-600 disabled:cursor-not-allowed disabled:opacity-50 dark:border-slate-600 dark:bg-slate-900/95 dark:text-slate-300 dark:hover:border-blue-500 dark:hover:bg-slate-800 dark:hover:text-blue-400"
              >
                <svg
                  className="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden
                >
                  <path d="M7 16V9l-3 3 3-3M17 8v7l-3-3 3-3" />
                </svg>
              </button>
            ) : undefined
          }
        />
      </div>
      {showRemove ? (
        <button
          type="button"
          onClick={() => removeStopAt(index)}
          title="Remove stop"
          aria-label="Remove stop"
          className="mt-0.5 flex h-[38px] w-8 shrink-0 items-center justify-center rounded-lg border border-slate-200 bg-white/95 text-lg leading-none text-slate-600 shadow-sm transition hover:border-red-400 hover:bg-red-50 hover:text-red-600 dark:border-slate-600 dark:bg-slate-900/95 dark:text-slate-300 dark:hover:border-red-500 dark:hover:bg-red-950/40 dark:hover:text-red-400"
        >
          ×
        </button>
      ) : (
        <span className="mt-0.5 w-8 shrink-0" aria-hidden />
      )}
    </div>
  )
}

export function RouteStopList({
  canPlan,
  onPlan,
}: {
  canPlan: boolean
  onPlan: () => void
}) {
  const routeStops = useRouteStore((s) => s.routeStops)
  const canSwap = useRouteStore((s) =>
    Boolean(
      routeStartPlace(s.routeStops) && routeEndPlace(s.routeStops),
    ),
  )
  const addStopBeforeDestination = useRouteStore(
    (s) => s.addStopBeforeDestination,
  )
  const reorderStopsByIndex = useRouteStore((s) => s.reorderStopsByIndex)

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { distance: 8 },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  )

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const oldIndex = routeStops.findIndex((r) => r.id === active.id)
    const newIndex = routeStops.findIndex((r) => r.id === over.id)
    if (oldIndex === -1 || newIndex === -1) return
    reorderStopsByIndex(oldIndex, newIndex)
  }

  const ids = routeStops.map((r) => r.id)

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragEnd={handleDragEnd}
    >
      <SortableContext items={ids} strategy={verticalListSortingStrategy}>
        <div className="space-y-2">
          {routeStops.map((row, index) => (
            <SortableStopRow
              key={row.id}
              row={row}
              index={index}
              total={routeStops.length}
              canPlan={canPlan}
              onPlan={onPlan}
              canSwap={canSwap}
            />
          ))}
        </div>
      </SortableContext>
      <button
        type="button"
        onClick={() => addStopBeforeDestination()}
        disabled={routeStops.length >= MAX_ROUTE_STOPS}
        className="mt-2 w-full rounded-lg border border-dashed border-slate-300 py-2 text-sm font-medium text-slate-600 transition hover:border-blue-400 hover:bg-slate-50 hover:text-blue-700 disabled:cursor-not-allowed disabled:opacity-50 dark:border-slate-600 dark:text-slate-300 dark:hover:border-blue-500 dark:hover:bg-slate-800 dark:hover:text-blue-300"
      >
        Add destination
      </button>
    </DndContext>
  )
}
