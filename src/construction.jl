function add_node!(bg::BondGraph, nodes)
    for node in nodes
        add_node!(bg, node)
    end
end

function add_node!(bg::BondGraph, node::AbstractNode)
    lg.add_vertex!(bg, node) || @warn "$node already in model"
end


function remove_node!(bg::BondGraph, nodes)
    for node in nodes
        remove_node!(bg, node)
    end
end

function remove_node!(bg::BondGraph, node::AbstractNode)
    lg.rem_vertex!(bg, node) || @warn "$node not in model"
    for bond in filter(bond -> node in bond, bg.bonds)
        lg.rem_edge!(bg, srcnode(bond), dstnode(bond))
    end
end


function connect!(bg::BondGraph, srcnode::AbstractNode, dstnode::AbstractNode; 
        srcportindex=nextfreeport(srcnode), dstportindex=nextfreeport(dstnode))
    srcnode in bg.nodes || error("$srcnode not found in bond graph")
    dstnode in bg.nodes || error("$dstnode not found in bond graph")
    srcport = Port(srcnode, srcportindex)
    dstport = Port(dstnode, dstportindex)
    return lg.add_edge!(bg, srcport, dstport)
end

function disconnect!(bg::BondGraph, node1::AbstractNode, node2::AbstractNode)
    # rem_edge! removes the bond regardless of the direction of the bond
    deleted_bond = lg.rem_edge!(bg, node1, node2)
    if isnothing(deleted_bond) # if returned nothing, try flipping node1 and node2
        deleted_bond = lg.rem_edge!(bg, node2, node1)
    end
    return deleted_bond
end


function swap!(bg::BondGraph, oldnode::AbstractNode, newnode::AbstractNode)
    numports(newnode) >= numports(oldnode) || error("New node must have a greater or equal number of ports to the old node")

    # may be a redundant check
    if !lg.has_vertex(bg, newnode)
        add_node!(bg, newnode)
    end

    srcnodes = lg.inneighbors(bg, oldnode)
    dstnodes = lg.outneighbors(bg, oldnode)
    remove_node!(bg, oldnode)
    
    for src in srcnodes
        connect!(bg, src, newnode)
    end
    for dst in dstnodes
        connect!(bg, newnode, dst)
    end
end

# TODO implement according to https://bondgraphtools.readthedocs.io/en/latest/api.html#BondGraphTools.expose
# function expose!()
    
# end


# Inserts an AbstractNode between two connected (bonded) nodes
# The direction of the original bond is preserved by this action
function insert_node!(bg::BondGraph, bond::Bond, newnode::AbstractNode)
    src = srcnode(bond)
    dst = dstnode(bond)

    disconnect!(bg, src, dst)

    try
        add_node!(bg, newnode)
        connect!(bg, src, newnode)
        connect!(bg, newnode, dst)
    catch e
        # if connection fails, reconnect original bond
        connect!(bg, src, dst)
        error(e)
    end
end
function insert_node!(bg::BondGraph, tuple::Tuple, newnode::AbstractNode)
    bonds = getbonds(bg, tuple)
    isempty(bonds) && error("$(tuple[1]) and $(tuple[2]) are not connected")
    insert_node!(bg, bonds[1], newnode)
end


function merge_nodes!(bg::BondGraph, node1::AbstractNode, node2::AbstractNode; junction=Junction(:𝟎))
    node1.metamodel == node2.metamodel || error("$(node1.name) must be the same type as $(node2.name)")

    # node1 taken as the node to keep
    for src in lg.inneighbors(bg, node1)
        junc_src = deepcopy(junction)
        bond = getbonds(bg, src, node1)[1]
        insert_node!(bg, bond, junc_src)
        swap!(bg, node2, junc_src)
    end
    for dst in lg.outneighbors(bg, node1)
        junc_dst = deepcopy(junction)
        bond = getbonds(bg, node1, dst)[1]
        insert_node!(bg, bond, junc_dst)
        swap!(bg, node2, junc_dst)
    end
end
function merge_nodes!(bg::BondGraph, node1::Junction, node2::Junction)
    # node1 taken as the node to keep
    # remove conflicting connections between junctions if they exist
    disconnect!(bg, node1, node2)
    shared_neighbors = intersect(lg.all_neighbors(bg, node1), lg.all_neighbors(bg, node2))
    for shared_neighbor in shared_neighbors
        disconnect!(bg, node2, shared_neighbor)
    end
    swap!(bg, node2, node1)
end


function simplify_junctions!(bg::BondGraph; remove_redundant=true, squash_identical=true)
    junctions = filter(n -> typeof(n) == Junction, bg.nodes)

    # Removes junctions with 2 or less connected ports
    if remove_redundant
        for j in junctions
            n_nbrs = length(lg.all_neighbors(bg, j))
            if n_nbrs == 2
                srcnode = lg.inneighbors(bg, j)[1]
                dstnode = lg.outneighbors(bg, j)[1]
                remove_node!(bg, j)
                # bond direction may not be preserved here
                connect!(bg, srcnode, dstnode)
            elseif n_nbrs < 2
                remove_node!(bg, j)
            end
        end
    end

    # Squashes identical copies of the same junction type into one junction
    if squash_identical
        for j in junctions, nbr in lg.all_neighbors(bg, j)
            lg.has_vertex(bg, j) || continue # in case j was removed
            if j.metamodel == nbr.metamodel
                merge_nodes!(bg, j, nbr)
            end
        end
    end
end