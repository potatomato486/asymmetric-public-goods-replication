"""Integer reactive strategies driven by a relative-contribution group signal."""
import numpy as np


def signal_indices(previous, endowments, levels=13, signal='mean'):
    """Nearest signal grid index; ties round upwards; exclude the focal player."""
    if not isinstance(levels, int) or levels < 2:
        raise ValueError('At least two signal levels required')
    q = np.asarray(previous)/np.asarray(endowments)
    n = q.shape[-1]
    if n < 2 or not np.isfinite(q).all() or np.any((q < 0) | (q > 1)):
        raise ValueError('Invalid previous relative contributions')
    if signal == 'mean':
        value = (q.sum(axis=-1, keepdims=True)-q)/(n-1)
    elif signal == 'minimum':
        value = np.stack([np.min(np.delete(q, i, axis=-1), axis=-1) for i in range(n)], axis=-1)
    else:
        raise ValueError('Unknown group signal')
    # A tiny tolerance removes floating error at exact rational half-grid ties.
    return np.clip(np.floor(value*(levels-1)+0.5+1e-12).astype(int), 0, levels-1)


def draw_profile(rng, endowments, levels, initial='random'):
    """Shape (agent, levels+1): first action followed by signal responses."""
    e = np.asarray(endowments, dtype=int)
    profile = rng.integers(0, e[:, None]+1, size=(len(e), levels+1))
    if initial == 'zero':
        profile[:] = 0
    elif initial == 'full':
        profile[:] = e[:, None]
    elif initial != 'random':
        raise ValueError('Unknown initialization')
    return profile


def validate_profiles(profiles, endowments, levels):
    s = np.asarray(profiles)
    e = np.asarray(endowments)
    if s.ndim != 3 or s.shape[1:] != (len(e), levels+1):
        raise ValueError('Invalid strategy shape')
    if not np.isfinite(s).all() or np.any(s != np.floor(s)) or np.any(s < 0) or np.any(s > e[None, :, None]):
        raise ValueError('Invalid strategy action')


def next_actions(profiles, previous, endowments, levels=13, signal='mean', order=None):
    """All decisions read previous; optional loop order verifies no schedule artifact."""
    indices = signal_indices(previous, endowments, levels, signal)
    batch, n = profiles.shape[:2]
    if order is None:
        return profiles[np.arange(batch)[:, None], np.arange(n)[None, :], indices+1]
    if sorted(order) != list(range(n)):
        raise ValueError('Order must contain every agent exactly once')
    chosen = np.empty((batch, n), dtype=int)
    for i in order:
        chosen[:, i] = profiles[np.arange(batch), i, indices[:, i]+1]
    return chosen
