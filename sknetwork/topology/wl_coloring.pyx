# distutils: language = c++
# cython: language_level=3

"""
Created on June 19, 2020
@author: Pierre Pebereau <pierre.pebereau@telecom-paris.fr>
@author: Alexis Barreaux <alexis.barreaux@telecom-paris.fr>
"""

from typing import Union

import numpy as np
cimport numpy as np
from scipy import sparse

from sknetwork.utils.base import Algorithm


cimport cython

cdef void c_wl_coloring(np.int32_t[:] indices, np.int32_t[:] indptr, np.int32_t[:]  labels) :
    cdef int n = indptr.shape[0] - 1

    # labels_i denotes the array of the labels at the i-th iteration.
    # labels_i_1 denotes the array of the labels at the i-1-th iteration.
    DTYPE = indices.dtype
    cdef np.int32_t[:]  labels_i = np.zeros(n, dtype = DTYPE)
    cdef np.int32_t[:]  labels_i_1 = np.zeros(n, dtype = DTYPE)

    cdef np.int32_t[:]  degres = np.array(indptr[1:]) - np.array(indptr[:-1])

    cdef np.int32_t[:,:]  multiset = [  np.zeros(degres[v], dtype = DTYPE) for v in range(n)  ]



    cdef np.int32_t[:,:]  long_label = np.zeros((n,2), dtype = DTYPE)


    cdef int i = 1
    cdef int u = 0

    while i < n and (labels_i_1 != labels_i).any() :

        labels_i = np.copy(labels_i_1) #Perf : ne pas utiliser copy? echanger les addresses ?


        for v in range(n):
            # 1
            # going through the neighbors of v.
            j = 0
            for u in indices[indptr[v]: indptr[v + 1]]:
                multiset[v][j] = labels_i_1[u]
                j+=1

            # 2
            multiset[v].sort() #TODO Tri par paquet

            long_label[v] = (int( str(labels_i_1[v]) + "".join(multiset[v])), v) #Efficace ?

        # 3

        long_label.sort(key=lambda x: x[0])  # sort along first axis

        new_hash = {}
        current_max = 0
        for (long_label_v, v) in long_label:
            if not (long_label_v in new_hash):
                new_hash[long_label_v] = current_max
                current_max += 1
            #  4

            labels_i[int(v)] = new_hash[long_label_v]

        i += 1

    labels = labels_i

    return






class WLColoring(Algorithm):
    """Weisefeler-Lehman algorithm for coloring/labeling graphs in order to check similarity.

    Attributes
    ----------
    labels_ : np.ndarray
        Label of each node.

    Example
    -------
    >>> from sknetwork.topology import WLColoring
    >>> from sknetwork.data import karate_club
    >>> wlcoloring = WLColoring()
    >>> adjacency = karate_club()
    >>> labels = wlcoloring.fit_transform(adjacency)


    References
    ----------
    * Douglas, B. L. (2011).
      'The Weisfeiler-Lehman Method and Graph Isomorphism Testing.
      <https://arxiv.org/pdf/1101.5211.pdf>`_
      Cornell University.


    * Shervashidze, N., Schweitzer, P., van Leeuwen, E. J., Melhorn, K., Borgwardt, K. M. (2010)
      'Weisfeiler-Lehman graph kernels.
      <https://people.mpi-inf.mpg.de/~mehlhorn/ftp/genWLpaper.pdf>`_
      Journal of Machine Learning Research 1, 2010.
    """

    def __init__(self):
        super(WLColoring, self).__init__()

        self.labels_ = None

    def fit(self, adjacency: Union[sparse.csr_matrix, np.ndarray]) -> 'WLColoring':
        """Fit algorithm to the data.

        Parameters
        ----------
        adjacency :
            Adjacency matrix of the graph.


        Returns
        -------
        self: :class:`WLColoring`
        """

        cdef np.int32_t[:]  indices = adjacency.indices
        cdef np.int32_t[:]  indptr = adjacency.indptr

        DTYPE = indices.dtype

        cdef np.int32_t[:]  labels = np.zeros(indptr.shape[0] - 1, dtype = DTYPE)
        c_wl_coloring(indices,  indptr, self.labels_)


        return self

    def fit_transform(self, *args, **kwargs) -> np.ndarray:
        """Fit algorithm to the data and return the labels. Same parameters as the ``fit`` method.

        Returns
        -------
        labels : np.ndarray
            Labels.
        """
        self.fit(*args, **kwargs)
        return self.labels_
