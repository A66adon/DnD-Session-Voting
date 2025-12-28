package ds.dnd.voting.repositories;

import ds.dnd.voting.model.Vote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface VoteRepository extends JpaRepository<Vote, Long> {

    @Query("SELECT vote FROM Vote vote JOIN vote.timeslots timeslot WHERE timeslot.votingWeek.id = :weekId")
    List<Vote> findVotesByVotingWeek(@Param("weekId") Long weekId);

}
