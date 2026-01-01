package ds.dnd.voting.repositories;

import ds.dnd.voting.model.TimeSlot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TimeSlotRepository extends JpaRepository<TimeSlot, Long> {

    @Query("SELECT COUNT(v) FROM Vote v JOIN v.timeslots t WHERE t.id = :timeSlotId")
    Long countVotesByTimeSlotId(@Param("timeSlotId") Long timeSlotId);

    @Query("SELECT COUNT(v) FROM Vote v JOIN v.preferredTimeSlots pts WHERE pts.id = :timeSlotId")
    Long countPreferredVotesByTimeSlotId(@Param("timeSlotId") Long timeSlotId);
}
